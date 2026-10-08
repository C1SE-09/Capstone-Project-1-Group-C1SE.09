"""Cấu hình Celery cho các background task của backend."""

import re

from celery import Celery

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
    include=["app.tasks.process_audio", "app.tasks.notifications"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    broker_connection_retry_on_startup=True,
    # Worker chỉ lấy trước đúng một task để không giữ nhiều audio chờ trong RAM.
    worker_prefetch_multiplier=1,
    # Task chưa ACK sẽ trở lại queue nếu worker mất kết nối/crash.
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    task_routes={
        "process_audio_task": {"queue": "audio"},
        "send_report_notifications": {"queue": "notifications"},
    },
)


@celery_app.task(name="ping")
def ping() -> str:
    """Task đơn giản để kiểm tra worker có kết nối Redis hay không."""
    return "pong"
