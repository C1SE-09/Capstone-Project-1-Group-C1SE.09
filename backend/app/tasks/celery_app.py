"""Cấu hình Celery cho các background task của backend."""

import re

from celery import Celery
from celery.schedules import crontab

from app.config import settings


def _derive_result_backend(broker_url: str) -> str:
    """Suy ra result backend từ broker URL.

    Broker dùng Redis DB 0 (chứa queue), result backend dùng DB 1 (chứa kết quả)
    để không lẫn kết quả task vào chung DB với queue.
    """
    # redis://host:6379/0 -> redis://host:6379/1
    return re.sub(r"/\d+$", "/1", broker_url)


# Redis URL được quản lý tập trung trong Settings và đọc từ REDIS_URL/.env.
celery_app = Celery(
    "kinderlog",
    broker=settings.redis_url,
    backend=_derive_result_backend(settings.redis_url),
    include=[
        "app.tasks.process_audio",
        "app.tasks.notifications",
        "app.tasks.bug_report_notifications",
        "app.tasks.attendance_notifications",
        "app.tasks.medication_notifications",
        "app.tasks.incident_notifications",
        "app.tasks.redispatch_stuck_audio",
        "app.tasks.report_response_notifications",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    # Broker (Redis) chết → `.delay()` phải ném lỗi NGAY, không retry vô hạn,
    # để request upload không bị treo. Lỗi được bắt ở `stt_dispatch_service`
    # và bản ghi sẽ được đẩy lại bởi cơ chế re-dispatch.
    #
    # Lưu ý: KHÔNG đặt `broker_connection_retry_on_startup=False` – worker cần
    # nhường nhị để kết nối lại Redis khi khởi động. Thay vào đó chặn retry ở
    # tầng publish (phía producer) – đây mới là chỗ cần fail nhanh.
    task_publish_retry=False,
    task_publish_retry_policy={"max_retries": 0},
    redis_socket_connect_timeout=2,
    redis_socket_timeout=2,
    redis_retry_on_timeout=False,
    # Timeout cho phía publish (producer gửi task): phải ngắn để request
    # upload không bị treo khi mạng yếu.
    broker_transport_options={
        "max_retries": 0,
        "socket_connect_timeout": 2,
        "socket_timeout": 2,
        "retry_on_timeout": False,
    },
    # Lịch tự động nhắc nhở điểm danh và dặn thuốc
    beat_schedule={
        "remind-unmarked-attendance-morning": {
            "task": "remind_unmarked_attendance",
            "schedule": crontab(hour=0, minute=40, day_of_week="1-5"),
        },
        # Nhắc uống thuốc buổi sáng lúc 09:00 VN (02:00 UTC) Thứ 2 - Thứ 6
        "remind-medication-morning": {
            "task": "remind_pending_medications",
            "schedule": crontab(hour=2, minute=0, day_of_week="1-5"),
            "args": ["morning"],
        },
        # Nhắc uống thuốc buổi trưa lúc 11:30 VN (04:30 UTC) Thứ 2 - Thứ 6
        "remind-medication-noon": {
            "task": "remind_pending_medications",
            "schedule": crontab(hour=4, minute=30, day_of_week="1-5"),
            "args": ["noon"],
        },
        # Nhắc uống thuốc buổi chiều lúc 14:30 VN (07:30 UTC) Thứ 2 - Thứ 6
        "remind-medication-afternoon": {
            "task": "remind_pending_medications",
            "schedule": crontab(hour=7, minute=30, day_of_week="1-5"),
            "args": ["afternoon"],
        },
        # Quét bản ghi âm bị kẹt (worker audio/RunPod tắt lúc upload) và đẩy lại.
        # Chạy mỗi 2 phút: đủ nhanh để cô không phải chờ, và không spam queue.
        "redispatch-stuck-voice-records": {
            "task": "redispatch_stuck_voice_records",
            "schedule": crontab(minute="*/2"),
        },
    },
    task_track_started=True,
    # Worker có thể chờ Redis sẵn sàng lúc khởi động (không sao, worker thì
    # được phép chờ). Producer (`.delay()`) thì fail nhanh – xem `conf.update`.
    broker_connection_retry_on_startup=True,
    # Worker chỉ lấy trước đúng một task để không giữ nhiều audio chờ trong RAM.
    worker_prefetch_multiplier=1,
    # Task chưa ACK sẽ trở lại queue nếu worker mất kết nối/crash.
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    task_routes={
        "process_audio_task": {"queue": "audio"},
        "send_report_notifications": {"queue": "notifications"},
        "send_leave_request_notifications": {"queue": "notifications"},
        "bug_report_notify_admin": {"queue": "notifications"},
        "bug_report_notify_user": {"queue": "notifications"},
        "send_medication_confirmed_notification": {"queue": "notifications"},
        "remind_pending_medications": {"queue": "notifications"},
        "send_health_incident_alert_task": {"queue": "notifications"},
        # Task quét bản ghi kẹt: chạy trên worker notifications (nhẹ, không cần GPU).
        "redispatch_stuck_voice_records": {"queue": "notifications"},
        # Phản hồi báo cáo (parent ↔ teacher): nhẹ, chạy cùng worker notifications.
        "notify_teacher_report_response": {"queue": "notifications"},
        "notify_parent_report_response_reply": {"queue": "notifications"},
    },
)


@celery_app.task(name="ping")
def ping() -> str:
    """Task đơn giản để kiểm tra worker có kết nối Redis hay không."""
    return "pong"
