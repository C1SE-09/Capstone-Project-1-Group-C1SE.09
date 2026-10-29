"""
backend/app/tasks/incident_notifications.py
===========================================
Gửi FCM Push Notification mức độ ưu tiên cao (< 30 giây) cho toàn bộ phụ huynh
liên kết khi giáo viên phát cảnh báo khẩn cấp tại lớp (Task #285).
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.database import SessionLocal
from app.models.health_incident import HealthIncident, HealthIncidentType
from app.services.notification_service import (
    child_parents_device_tokens,
    is_invalid_token,
    send_push_notification,
)
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)

INCIDENT_LABELS = {
    HealthIncidentType.HIGH_FEVER.value: "Sốt cao",
    HealthIncidentType.SEVERE_INJURY.value: "Tai nạn / Chấn thương",
    HealthIncidentType.ACUTE_ALLERGY.value: "Dị ứng cấp tính",
    HealthIncidentType.OTHER.value: "Sự cố sức khỏe",
}


def deliver_health_incident_alert(
    db: Session,
    incident_id_str: str,
) -> dict:
    """
    Gửi push notification khẩn cấp tới tất cả thiết bị phụ huynh của trẻ (< 30s).
    """
    try:
        inc_uuid = uuid.UUID(incident_id_str)
    except ValueError:
        logger.warning("[IncidentNotify] incident_id không hợp lệ: %s", incident_id_str)
        return {"sent": 0, "removed": 0, "reason": "invalid_uuid"}

    incident = db.scalar(
        select(HealthIncident)
        .options(
            joinedload(HealthIncident.child),
            joinedload(HealthIncident.reported_by),
        )
        .where(HealthIncident.incident_id == inc_uuid)
    )
    if not incident or not incident.child:
        logger.warning("[IncidentNotify] Không tìm thấy sự cố hoặc thông tin trẻ: incident=%s", incident_id_str)
        return {"sent": 0, "removed": 0, "reason": "not_found"}

    child = incident.child
    child_name = child.full_name.strip() if child.full_name else (child.nickname or "bé")
    reporter = incident.reported_by
    teacher = reporter.teacher if reporter and hasattr(reporter, "teacher") else None
    teacher_name = (
        teacher.full_name
        if teacher and teacher.full_name
        else (getattr(reporter, "full_name", None) or getattr(reporter, "username", None) or "Cô giáo phụ trách")
    )
    teacher_phone = teacher.phone if teacher and teacher.phone else ""
    incident_label = INCIDENT_LABELS.get(incident.incident_type, "Sự cố sức khỏe")

    # Giờ theo múi giờ Việt Nam
    vn_tz = timezone(timedelta(hours=7))
    reported_time = incident.reported_at.astimezone(vn_tz) if incident.reported_at else datetime.now(vn_tz)
    time_str = reported_time.strftime("%H:%M")

    # Lấy token phụ huynh
    tokens = child_parents_device_tokens(db, child.child_id)
    if not tokens:
        logger.info("[IncidentNotify] Phụ huynh của bé %s chưa đăng ký thiết bị nhận push", child_name)
        return {"sent": 0, "removed": 0, "reason": "no_device_tokens"}

    title = f"🚨 KHẨN CẤP: Bé {child_name} gặp sự cố tại lớp"
    body = (
        f"Lúc {time_str}, Cô {teacher_name} phát cảnh báo: Bé bị {incident_label}. "
        f"{incident.description}. Xin phụ huynh liên hệ gấp với cô giáo!"
    )
    data = {
        "type": "health_incident_alert",
        "incident_id": str(incident.incident_id),
        "child_id": str(child.child_id),
        "child_name": child_name,
        "incident_type": incident_label,
        "teacher_name": teacher_name,
        "teacher_phone": teacher_phone,
        "created_at": reported_time.isoformat(),
        "description": incident.description or "",
        "temperature": str(incident.temperature) if incident.temperature is not None else "",
        "priority": "emergency",
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
                channel_id="kinderlog_emergency",
            )
            sent += 1
        except Exception as error:
            if is_invalid_token(error):
                db.delete(device_token)
                removed += 1
                logger.info("[IncidentNotify] Đã xoá token không hợp lệ: %s", device_token.token)
            else:
                logger.warning("[IncidentNotify] Gửi alert thất bại cho token=%s: %s", device_token.token, error)

    if removed > 0:
        db.commit()

    logger.info("[IncidentNotify] Hoàn thành bắn alert khẩn cấp cho bé %s: sent=%d, removed=%d", child_name, sent, removed)
    return {"sent": sent, "removed": removed, "reason": "success"}


def deliver_health_incident_alert_sync(incident_id_str: str) -> dict:
    """Hàm wrapper mở SessionLocal dành cho FastAPI BackgroundTasks."""
    db: Session = SessionLocal()
    try:
        return deliver_health_incident_alert(db, incident_id_str)
    finally:
        db.close()


@celery_app.task(name="send_health_incident_alert_task", queue="notifications")
def send_health_incident_alert_task(incident_id_str: str) -> dict:
    """Task chạy nền trên Celery worker."""
    return deliver_health_incident_alert_sync(incident_id_str)
