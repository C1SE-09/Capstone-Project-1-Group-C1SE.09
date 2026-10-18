"""Celery task: gửi push notification cho phụ huynh khi báo cáo được gửi.

Luồng: ``_send_one_report`` commit trạng thái SENT → đẩy job
``send_report_notifications`` vào queue ``notifications`` → worker gửi FCM
tới mọi device token của hộ gia đình, tự xoá token không còn hợp lệ và
retry khi lỗi tạm thời.
"""

from __future__ import annotations

import logging
import uuid

from app.core.database import SessionLocal
from app.models.report import DailyReport
from app.services.notification_service import (
    is_invalid_token,
    parent_device_tokens,
    send_push_notification,
)
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _deliver_report_notification(db, report_id: str, is_update: bool = False) -> dict:
    """Gửi push tới toàn bộ thiết bị phụ huynh của trẻ; trả về thống kê.

    Tách khỏi task để unit-test được với session giả (xem tests/test_notifications.py).
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
    if child is None:
        logger.info("[Notify] Báo cáo không có thông tin trẻ (report_id=%s)", report_id)
        return {"sent": 0, "removed": 0, "reason": "no_child"}

    # N-N: Thu thập toàn bộ parent_id từ parent_links và parent_id trực tiếp
    parent_ids: list[uuid.UUID] = []
    p_links = getattr(child, "parent_links", None)
    if isinstance(p_links, list) and p_links:
        parent_ids = [link.parent_id for link in p_links if getattr(link, "parent_id", None)]
    direct_pid = getattr(child, "parent_id", None)
    if direct_pid and isinstance(direct_pid, uuid.UUID) and direct_pid not in parent_ids:
        parent_ids.append(direct_pid)
    elif direct_pid and not parent_ids and not isinstance(direct_pid, uuid.UUID):
        parent_ids.append(direct_pid)

    if not parent_ids:
        logger.info("[Notify] Trẻ chưa liên kết phụ huynh (report_id=%s)", report_id)
        return {"sent": 0, "removed": 0, "reason": "no_parent"}

    child_name = child.full_name.strip() if child.full_name else (child.nickname or "bé")

    if len(parent_ids) == 1:
        tokens = parent_device_tokens(db, parent_ids[0])
    else:
        tokens = (
            db.query(DeviceToken)
            .join(User, DeviceToken.user_id == User.user_id)
            .filter(User.parent_id.in_(parent_ids))
            .all()
        )
    if not tokens:
        logger.info("[Notify] Phụ huynh chưa đăng ký thiết bị (bé %s)", child_name)
        return {"sent": 0, "removed": 0, "reason": "no_device_tokens"}

    title = "KinderLog"
    if is_update:
        report_date = report.report_date.strftime("%d/%m") if report.report_date else ""
        body = f"Báo cáo ngày {report_date} của {child_name} đã được cập nhật"
        action_type = "report_updated"
    else:
        body = f"Báo cáo hàng ngày của {child_name} đã sẵn sàng"
        action_type = "report_sent"

    data = {
        "type": action_type,
        "report_id": str(report.daily_report_id),
        "child_id": str(report.child_id),
    }

    sent = 0
    removed = 0
    for device_token in tokens:
        try:
            send_push_notification(
                token=device_token.token,
                title=title,
                body=body,
                data=data,
            )
            sent += 1
        except Exception as error:
            # Một token lỗi không được chặn các token còn lại.
            if is_invalid_token(error):
                db.delete(device_token)
                removed += 1
                logger.info(
                    "[Notify] Đã xoá token không hợp lệ: %s", device_token.token
                )
            else:
                logger.exception(
                    "[Notify] Gửi thất bại cho token=%s", device_token.token
                )

    db.commit()
    logger.info(
        "[Notify] report_id=%s bé=%s sent=%d removed=%d",
        report_id,
        child_name,
        sent,
        removed,
    )
    return {"sent": sent, "removed": removed}


@celery_app.task(
    bind=True,
    name="send_report_notifications",
    max_retries=3,
    default_retry_delay=30,
)
def send_report_notifications(self, report_id: str, is_update: bool = False) -> dict:
    """Celery entry: mở session rồi gọi phần xử lý thuần (dễ test)."""
    db = SessionLocal()
    try:
        return _deliver_report_notification(db, report_id, is_update=is_update)
    except Exception as error:
        db.rollback()
        logger.exception(
            "[Notify] Task lỗi report_id=%s — sẽ thử lại", report_id
        )
        raise self.retry(exc=error)
    finally:
        db.close()
