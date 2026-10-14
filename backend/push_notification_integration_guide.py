"""KinderLog - Hướng dẫn và Code Độc Lập cho Chức Năng Push Notification.

Tài liệu & Module này được thiết kế độc lập, không can thiệp trực tiếp vào mã nguồn
hiện tại để đảm bảo tính an toàn dữ liệu, không ảnh hưởng đến các luồng nghiệp vụ khác
và giúp nhóm phát triển (team) có thể review, tích hợp thủ công và chạy CI dễ dàng nhất.

================================================================================
MỤC LỤC & HƯỚNG DẪN TÍCH HỢP TỪNG BƯỚC (STEP-BY-STEP INTEGRATION GUIDE)
================================================================================

1. BẢO MẬT & AN TOÀN DỮ LIỆU:
   - Token Isolation: Token không hợp lệ (UnregisteredError) được dọn dẹp riêng lẻ;
     lỗi ở 1 token không làm gián đoạn việc gửi thông báo tới các token khác.
   - Idempotency & Fault Tolerance: Việc gửi push notification qua Celery được bọc
     trong khối try-except sau khi commit DB; lỗi từ dịch vụ ngoài (FCM/Apple) không
     bao giờ làm rollback giao dịch lưu báo cáo của giáo viên.
   - Data Minimization: Payload data chỉ truyền các định danh cần thiết (report_id, child_id, type),
     không đính kèm thông tin nhạy cảm của trẻ em.

2. CÁC FILE CẦN CẬP NHẬT TRONG MÃ NGUỒN CHÍNH:
   - File 1: `backend/app/services/notification_service.py`
     -> Bổ sung cấu hình AndroidConfig (priority high, sound, wake screen) & APNSConfig vào hàm gửi.
   - File 2: `backend/app/tasks/notifications.py`
     -> Bổ sung tham số `is_update`, ưu tiên `child.full_name`, tiêu đề "KinderLog".
   - File 3: `backend/app/api/teacher.py`
     -> Kiểm tra báo cáo đã gửi trước đó chưa (`was_already_sent`) để truyền cờ `is_update=True/False`.

(Xem chi tiết code mẫu và vị trí cần thêm ở phần bên dưới).
"""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime
from typing import Any

from app.models.report import DailyReport
from app.services.notification_service import (
    get_firebase_app,
    is_invalid_token,
    parent_device_tokens,
)
from firebase_admin import messaging
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Tên kênh thông báo trên Android (phải khớp với kênh đăng ký trên mobile)
KINDERLOG_NOTIFICATION_CHANNEL_ID = "kinderlog_reports"
KINDERLOG_NOTIFICATION_TITLE = "KinderLog"


# ==============================================================================
# 1. HÀM XÂY DỰNG NỘI DUNG VÀ PAYLOAD (ĐẠT CHUẨN TIÊU CHÍ CHẤP NHẬN AC 1 & AC 2)
# ==============================================================================

def build_report_notification_payload(
    report: DailyReport,
    is_update: bool = False,
) -> dict[str, Any]:
    """Xây dựng nội dung tiêu đề, nội dung và data payload cho báo cáo.

    Tiêu chuẩn AC:
    - AC 1.1: Gửi mới -> Title: "KinderLog", Body: "Báo cáo hàng ngày của [Họ và tên] đã sẵn sàng"
    - AC 1.2: Cập nhật -> Title: "KinderLog", Body: "Báo cáo ngày dd/MM của [Họ và tên] đã được cập nhật"
    - Luôn ưu tiên họ và tên đầy đủ: `child.full_name`.

    :param report: Đối tượng DailyReport (SQLAlchemy model)
    :param is_update: True nếu là báo cáo gửi lại/chỉnh sửa, False nếu là gửi mới lần đầu
    :return: Dict chứa title, body, data_payload
    """
    child = report.child
    if not child or not child.full_name:
        child_name = "bé"
    else:
        # Tuân thủ yêu cầu: Luôn luôn ưu tiên Họ và tên của bé
        child_name = child.full_name.strip()

    title = KINDERLOG_NOTIFICATION_TITLE

    if is_update:
        # Định dạng ngày báo cáo theo dd/MM (ví dụ: 14/10)
        report_date_str = (
            report.report_date.strftime("%d/%m")
            if hasattr(report, "report_date") and report.report_date
            else datetime.now(UTC).strftime("%d/%m")
        )
        body = f"Báo cáo ngày {report_date_str} của {child_name} đã được cập nhật"
        action_type = "report_updated"
    else:
        body = f"Báo cáo hàng ngày của {child_name} đã sẵn sàng"
        action_type = "report_sent"

    data_payload = {
        "type": action_type,
        "report_id": str(report.daily_report_id),
        "child_id": str(report.child_id),
    }

    return {
        "title": title,
        "body": body,
        "data": data_payload,
    }


# ==============================================================================
# 2. HÀM GỬI PUSH THÔNG BÁO VỚI CẤU HÌNH HIGH PRIORITY & ÂM THANH MẶC ĐỊNH
# ==============================================================================

def send_push_notification_enhanced(
    *,
    token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
    channel_id: str = KINDERLOG_NOTIFICATION_CHANNEL_ID,
) -> str:
    """Gửi push notification qua FCM với cấu hình High Priority, Sound và Wake Screen.

    Tuân thủ AC 2:
    - Android: priority='high', notification channel có âm thanh mặc định, rung và bật sáng màn hình.
    - iOS (APNS): sound='default' để phát chuông hệ thống khi app đang đóng/chạy ngầm.

    :param token: FCM Device Registration Token của phụ huynh.
    :param title: Tiêu đề thông báo ("KinderLog").
    :param body: Nội dung thông báo.
    :param data: Dữ liệu đính kèm (type, report_id, child_id).
    :param channel_id: ID Notification Channel trên Android.
    :return: message_id trả về từ Firebase.
    """
    # Cấu hình chuyên biệt cho nền tảng Android (đáp ứng tiêu chí sáng màn hình và âm thanh)
    android_config = messaging.AndroidConfig(
        priority="high",
        notification=messaging.AndroidNotification(
            title=title,
            body=body,
            channel_id=channel_id,
            sound="default",
            default_sound=True,
            default_vibrate_timings=True,
            visibility="public",  # Hiển thị đầy đủ nội dung trên màn hình khoá
        ),
    )

    # Cấu hình chuyên biệt cho nền tảng iOS (APNs)
    apns_config = messaging.APNSConfig(
        headers={"apns-priority": "10"},
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                sound="default",
                badge=1,
            )
        ),
    )

    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data or {},
        token=token,
        android=android_config,
        apns=apns_config,
    )

    return messaging.send(
        message,
        app=get_firebase_app(),
    )


# ==============================================================================
# 3. HÀM PHÂN PHÁI THÔNG BÁO TỚI PHỤ HUYNH (DELIVERY ENGINE)
# ==============================================================================

def deliver_report_notification_enhanced(
    db: Session,
    report_id: str,
    is_update: bool = False,
    sender_func=send_push_notification_enhanced,
) -> dict[str, Any]:
    """Phân phối thông báo báo cáo tới tất cả thiết bị của phụ huynh.

    Đặc điểm an toàn:
    1. Kiểm tra tính hợp lệ của report_id và child.
    2. Lấy toàn bộ device token của các tài khoản phụ huynh liên kết (AC 4.1).
    3. Gửi đồng loạt, ghi nhận số lượng thành công.
    4. Xoá token chết (UnregisteredError) khỏi DB mà không ảnh hưởng các token khác.
    5. Không làm gián đoạn dữ liệu nếu xảy ra lỗi.
    """
    try:
        report_uuid = uuid.UUID(report_id)
    except ValueError:
        logger.warning("[Notify] report_id không hợp lệ: %s", report_id)
        return {"sent": 0, "removed": 0, "reason": "invalid_report_id"}

    report = (
        db.query(DailyReport)
        .filter(DailyReport.daily_report_id == report_uuid)
        .first()
    )
    if report is None:
        logger.warning("[Notify] Không tìm thấy report_id=%s", report_id)
        return {"sent": 0, "removed": 0, "reason": "report_not_found"}

    child = report.child
    if child is None or child.parent_id is None:
        logger.info("[Notify] Trẻ chưa liên kết phụ huynh (report_id=%s)", report_id)
        return {"sent": 0, "removed": 0, "reason": "no_parent"}

    tokens = parent_device_tokens(db, child.parent_id)
    if not tokens:
        logger.info("[Notify] Phụ huynh chưa đăng ký thiết bị (bé %s)", child.full_name)
        return {"sent": 0, "removed": 0, "reason": "no_device_tokens"}

    # Xây dựng payload thông báo
    payload = build_report_notification_payload(report, is_update=is_update)

    sent = 0
    removed = 0
    for device_token in tokens:
        try:
            sender_func(
                token=device_token.token,
                title=payload["title"],
                body=payload["body"],
                data=payload["data"],
            )
            sent += 1
        except Exception as error:
            if is_invalid_token(error):
                db.delete(device_token)
                removed += 1
                logger.info("[Notify] Đã xoá token không hợp lệ: %s", device_token.token)
            else:
                logger.exception("[Notify] Gửi thất bại cho token=%s", device_token.token)

    if removed > 0:
        db.commit()

    logger.info(
        "[Notify] Hoàn tất: report_id=%s, bé=%s, is_update=%s, sent=%d, removed=%d",
        report_id,
        child.full_name,
        is_update,
        sent,
        removed,
    )
    return {"sent": sent, "removed": removed, "title": payload["title"], "body": payload["body"]}


# ==============================================================================
# 4. HƯỚNG DẪN TÍCH HỢP VÀO SOURCE CODE CHÍNH (DÀNH CHO TEAM)
# ==============================================================================
"""
BƯỚC 1: CẬP NHẬT `backend/app/services/notification_service.py`
-------------------------------------------------------------
Thay thế hàm `send_push_notification` bằng phiên bản có cấu hình AndroidConfig & APNSConfig:

```python
def send_push_notification(
    *,
    token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> str:
    android_config = messaging.AndroidConfig(
        priority="high",
        notification=messaging.AndroidNotification(
            title=title,
            body=body,
            channel_id="kinderlog_reports",
            sound="default",
            default_sound=True,
            default_vibrate_timings=True,
            visibility="public",
        ),
    )
    apns_config = messaging.APNSConfig(
        headers={"apns-priority": "10"},
        payload=messaging.APNSPayload(aps=messaging.Aps(sound="default", badge=1)),
    )
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
        token=token,
        android=android_config,
        apns=apns_config,
    )
    return messaging.send(message, app=get_firebase_app())
```

BƯỚC 2: CẬP NHẬT `backend/app/tasks/notifications.py`
-----------------------------------------------------
1. Trong hàm `_deliver_report_notification(db, report_id: str, is_update: bool = False)`:
   - Sửa dòng gán tên bé:
       `child_name = child.full_name or child.nickname or "bé"`
   - Sửa tiêu đề và nội dung:
       title = "KinderLog"
       if is_update:
           body = f"Báo cáo ngày {report.report_date.strftime('%d/%m')} của {child_name} đã được cập nhật"
           data_type = "report_updated"
       else:
           body = f"Báo cáo hàng ngày của {child_name} đã sẵn sàng"
           data_type = "report_sent"
   - Cập nhật data:
       data = {
           "type": data_type,
           "report_id": str(report.daily_report_id),
           "child_id": str(report.child_id),
       }
2. Trong Celery task `send_report_notifications(self, report_id: str, is_update: bool = False)`:
   - Thêm tham số `is_update: bool = False` và truyền vào `_deliver_report_notification(db, report_id, is_update)`.

BƯỚC 3: CẬP NHẬT `backend/app/api/teacher.py`
--------------------------------------------
1. Trong helper `_queue_report_notification(db, report, child, is_update: bool = False)`:
   - Bổ sung tham số `is_update`:
       `send_report_notifications.delay(str(report.daily_report_id), is_update=is_update)`
2. Trong endpoint `send_daily_report` (khoảng dòng 1330-1350):
   - Nhận diện cờ chỉnh sửa trước khi commit:
       `was_already_sent = (report.status == SENT_STATUS or report.sent_at is not None)`
       `is_update = bool(was_already_sent)`
   - Khi gọi `_queue_report_notification`:
       `targeted_devices = _queue_report_notification(db, report, child, is_update=is_update)`
3. Trong endpoint `publish_report` (khoảng dòng 910-925):
   - Tương tự, nếu `report.published_at` đã tồn tại từ trước:
       `is_update = report.published_at is not None`
       `_queue_report_notification(db, report, report.child, is_update=is_update)`
"""
