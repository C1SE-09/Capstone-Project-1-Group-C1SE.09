"""
backend/app/tasks/medication_notifications.py
=============================================
Celery background task & notification delivery:
Gửi FCM Push Notification cho phụ huynh khi giáo viên xác nhận đã cho trẻ uống thuốc.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.database import SessionLocal
from app.models.medication import MedicationLog, MedicationRequest
from app.services.notification_service import (
    child_parents_device_tokens,
    is_invalid_token,
    send_push_notification,
)
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)

SESSION_LABELS = {
    "morning": "Sáng",
    "noon": "Trưa",
    "afternoon": "Chiều",
}


def deliver_medication_notification(
    db: Session,
    request_id_str: str,
    log_id_str: str,
) -> dict:
    """
    Gửi push notification tới toàn bộ thiết bị của phụ huynh được liên kết với trẻ.
    Hàm này được tách ra để có thể test độc lập hoặc chạy qua background task.
    """
    try:
        req_uuid = uuid.UUID(request_id_str)
        log_uuid = uuid.UUID(log_id_str)
    except ValueError:
        logger.warning("[MedicationNotify] UUID không hợp lệ: req=%s, log=%s", request_id_str, log_id_str)
        return {"sent": 0, "removed": 0, "reason": "invalid_uuid"}

    # 1. Truy vấn đơn dặn thuốc và lịch sử uống
    med_req = db.scalar(
        select(MedicationRequest)
        .options(joinedload(MedicationRequest.child))
        .where(MedicationRequest.request_id == req_uuid)
    )
    if not med_req or not med_req.child:
        logger.warning("[MedicationNotify] Không tìm thấy đơn thuốc hoặc thông tin trẻ: req=%s", request_id_str)
        return {"sent": 0, "removed": 0, "reason": "not_found"}

    log_entry = db.scalar(
        select(MedicationLog)
        .options(joinedload(MedicationLog.given_by))
        .where(MedicationLog.log_id == log_uuid)
    )
    if not log_entry:
        logger.warning("[MedicationNotify] Không tìm thấy log_id=%s", log_id_str)
        return {"sent": 0, "removed": 0, "reason": "log_not_found"}

    child = med_req.child
    child_name = child.full_name.strip() if child.full_name else (child.nickname or "bé")
    teacher_name = log_entry.given_by.full_name if log_entry.given_by else "Cô giáo"

    # Định dạng giờ theo múi giờ Việt Nam (UTC+7)
    vn_tz = timezone(timedelta(hours=7))
    if log_entry.given_at:
        local_time = log_entry.given_at.astimezone(vn_tz)
    else:
        local_time = datetime.now(vn_tz)
    time_str = local_time.strftime("%H:%M")

    session_label = SESSION_LABELS.get(log_entry.session.lower(), log_entry.session)

    # 2. Lấy danh sách token thiết bị của toàn bộ phụ huynh
    tokens = child_parents_device_tokens(db, child.child_id)
    if not tokens:
        logger.info("[MedicationNotify] Phụ huynh chưa đăng ký thiết bị nhận thông báo (bé %s)", child_name)
        return {"sent": 0, "removed": 0, "reason": "no_device_tokens"}

    title = f"Bé {child_name} đã uống thuốc"
    body = (
        f"Cô {teacher_name} đã cho bé uống thuốc {med_req.medication_name} "
        f"({med_req.dosage}) buổi {session_label} lúc {time_str}."
    )
    data = {
        "type": "medication_confirmed",
        "request_id": str(med_req.request_id),
        "child_id": str(child.child_id),
        "log_id": str(log_entry.log_id),
        "session": log_entry.session,
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
                channel_id="kinderlog_medication",
            )
            sent += 1
        except Exception as error:
            if is_invalid_token(error):
                db.delete(device_token)
                removed += 1
                logger.info("[MedicationNotify] Đã xoá token rác không hợp lệ: %s", device_token.token)
            else:
                logger.warning("[MedicationNotify] Gửi push thất bại cho token=%s: %s", device_token.token, error)

    if removed > 0:
        db.commit()

    logger.info("[MedicationNotify] Hoàn thành gửi thông báo dặn thuốc bé %s: sent=%d, removed=%d", child_name, sent, removed)
    return {"sent": sent, "removed": removed, "reason": "success"}


def deliver_medication_notification_sync(request_id_str: str, log_id_str: str) -> dict:
    """Hàm wrapper mở SessionLocal dành cho FastAPI BackgroundTasks."""
    db: Session = SessionLocal()
    try:
        return deliver_medication_notification(db, request_id_str, log_id_str)
    finally:
        db.close()


@celery_app.task(name="send_medication_confirmed_notification", queue="notifications")
def send_medication_confirmed_notification(request_id_str: str, log_id_str: str) -> dict:
    """Task chạy nền Celery worker gửi push notification khi đã cho uống thuốc."""
    return deliver_medication_notification_sync(request_id_str, log_id_str)


@celery_app.task(name="remind_pending_medications", queue="notifications")
def remind_pending_medications(session_name: str | None = None, target_date_str: str | None = None) -> dict:
    """
    Celery background worker chạy định kỳ lúc 09:00, 11:30, 14:30 hàng ngày:
    - Quét các đơn dặn thuốc chưa được cho uống theo từng lớp.
    - Gửi grouped reminder push notification tới toàn bộ giáo viên phụ trách của lớp.
    """
    from datetime import date
    from app.services.medication_reminder_service import send_grouped_medication_reminder

    target_date = date.fromisoformat(target_date_str) if target_date_str else None
    db: Session = SessionLocal()
    try:
        return send_grouped_medication_reminder(
            db=db,
            target_date=target_date,
            session_name=session_name,
        )
    finally:
        db.close()

