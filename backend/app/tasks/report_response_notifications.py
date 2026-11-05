"""
app/tasks/report_response_notifications.py
==========================================
Celery task gửi push notification cho "Phản hồi báo cáo".

Luồng:
    Phụ huynh gửi phản hồi  → push cho giáo viên (data.type = "report_response")
    Giáo viên trả lời       → push cho phụ huynh (data.type = "report_response_reply")

Pattern (giống ``app/tasks/notifications.py``):
    - Hàm thuần ``_deliver_*`` nhận session → dễ unit-test.
    - Celery wrapper mở session, gọi hàm thuần, retry khi lỗi tạm thời.
    - Một device token lỗi không được chặn các token còn lại.
    - Lỗi FCM KHÔNG làm fail task (đã log) — thông báo là best-effort.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.device_token import DeviceToken
from app.models.report import DailyReport
from app.models.report_response import ReportResponse
from app.models.user import User
from app.services.notification_service import (
    is_invalid_token,
    send_push_notification,
)
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)

#: Channel FCM riêng cho phản hồi báo cáo (client có thể cấu hình âm thanh riêng).
CHANNEL_ID = "kinderlog_report_responses"


# ===========================================================================
# Helpers
# ===========================================================================


def _teacher_device_tokens(db: Session, teacher_id: uuid.UUID | None) -> list[DeviceToken]:
    """Device token của giáo viên (qua user.teacher_id) + admin."""
    if teacher_id is None:
        return []
    return (
        db.query(DeviceToken)
        .join(User, DeviceToken.user_id == User.user_id)
        .filter(User.teacher_id == teacher_id)
        .all()
    )


def _parent_device_tokens(db: Session, child_id: uuid.UUID | None) -> list[DeviceToken]:
    """Device token của mọi phụ huynh được liên kết với bé."""
    if child_id is None:
        return []
    from app.services.notification_service import child_parents_device_tokens

    return child_parents_device_tokens(db, child_id)


def _send_pushes(
    tokens: list[DeviceToken],
    *,
    title: str,
    body: str,
    data: dict[str, str],
    db: Session,
) -> dict[str, int]:
    """Gửi push tới nhiều token; tự xoá token không còn hợp lệ."""
    if not tokens:
        return {"sent": 0, "removed": 0, "failed": 0}

    sent = 0
    removed = 0
    failed = 0
    for device_token in tokens:
        try:
            send_push_notification(
                token=device_token.token,
                title=title,
                body=body,
                data=data,
                channel_id=CHANNEL_ID,
            )
            sent += 1
        except Exception as error:
            if is_invalid_token(error):
                db.delete(device_token)
                removed += 1
                logger.info(
                    "[ResponseNotify] Đã xoá token không hợp lệ: %s", device_token.token
                )
            else:
                failed += 1
                logger.warning(
                    "[ResponseNotify] Gửi push thất bại cho token=%s: %s",
                    device_token.token,
                    error,
                )
    if removed:
        db.commit()
    return {"sent": sent, "removed": removed, "failed": failed}


def _child_display_name(db: Session, report: DailyReport) -> str:
    """Tên hiển thị của bé (dùng trong nội dung push)."""
    if report.child is not None:
        return report.child.full_name.strip() or (report.child.nickname or "bé")
    return "bé"


def _author_display_name(response: ReportResponse, fallback: str) -> str:
    """Tên hiển thị của người viết phản hồi (fallback nếu không có profile)."""
    author = response.author
    if author is None:
        return fallback
    if author.teacher is not None and author.teacher.full_name:
        return author.teacher.full_name
    if author.parent is not None and author.parent.full_name:
        return author.parent.full_name
    return author.username or fallback


# ===========================================================================
# 1) Phụ huynh gửi phản hồi → notify giáo viên
# ===========================================================================


def _deliver_response_to_teacher(db: Session, response_id: str) -> dict[str, Any]:
    """Thuần: gửi push cho giáo viên khi phụ huynh gửi phản hồi."""
    try:
        response_uuid = uuid.UUID(response_id)
    except ValueError:
        logger.warning("[ResponseNotify] response_id không hợp lệ: %s", response_id)
        return {"sent": 0, "removed": 0, "reason": "invalid_response_id"}

    response = (
        db.query(ReportResponse)
        .filter(ReportResponse.response_id == response_uuid)
        .first()
    )
    if response is None:
        logger.warning("[ResponseNotify] Không tìm thấy response_id=%s", response_id)
        return {"sent": 0, "removed": 0, "reason": "response_not_found"}

    report = response.daily_report
    if report is None:
        return {"sent": 0, "removed": 0, "reason": "no_report"}

    child_name = _child_display_name(db, report)
    author_name = _author_display_name(response, "Phụ huynh")

    tokens = _teacher_device_tokens(db, report.teacher_id)
    if not tokens:
        logger.info(
            "[ResponseNotify] Giáo viên chưa đăng ký thiết bị (báo cáo %s)", report.daily_report_id
        )
        return {"sent": 0, "removed": 0, "reason": "no_device_tokens"}

    title = "Phản hồi báo cáo mới"
    body = f"{author_name} đã phản hồi về báo cáo của {child_name}."
    data = {
        "type": "report_response",
        "response_id": str(response.response_id),
        "report_id": str(report.daily_report_id),
        "child_id": str(report.child_id) if report.child_id else "",
    }

    return _send_pushes(tokens, title=title, body=body, data=data, db=db)


# ===========================================================================
# 2) Giáo viên trả lời → notify phụ huynh
# ===========================================================================


def _deliver_reply_to_parent(db: Session, response_id: str) -> dict[str, Any]:
    """Thuần: gửi push cho phụ huynh khi giáo viên trả lời."""
    try:
        response_uuid = uuid.UUID(response_id)
    except ValueError:
        logger.warning("[ResponseNotify] response_id không hợp lệ: %s", response_id)
        return {"sent": 0, "removed": 0, "reason": "invalid_response_id"}

    response = (
        db.query(ReportResponse)
        .filter(ReportResponse.response_id == response_uuid)
        .first()
    )
    if response is None:
        logger.warning("[ResponseNotify] Không tìm thấy response_id=%s", response_id)
        return {"sent": 0, "removed": 0, "reason": "response_not_found"}

    report = response.daily_report
    if report is None:
        return {"sent": 0, "removed": 0, "reason": "no_report"}

    child_name = _child_display_name(db, report)
    author_name = _author_display_name(response, "Giáo viên")

    tokens = _parent_device_tokens(db, report.child_id)
    if not tokens:
        logger.info(
            "[ResponseNotify] Phụ huynh chưa đăng ký thiết bị (báo cáo %s)", report.daily_report_id
        )
        return {"sent": 0, "removed": 0, "reason": "no_device_tokens"}

    title = "Giáo viên đã trả lời"
    body = f"{author_name} đã trả lời phản hồi về báo cáo của {child_name}."
    data = {
        "type": "report_response_reply",
        "response_id": str(response.response_id),
        "report_id": str(report.daily_report_id),
        "child_id": str(report.child_id) if report.child_id else "",
    }

    return _send_pushes(tokens, title=title, body=body, data=data, db=db)


# ===========================================================================
# 3) Celery tasks (wrappers)
# ===========================================================================


@celery_app.task(
    bind=True,
    name="notify_teacher_report_response",
    max_retries=3,
    default_retry_delay=30,
)
def notify_teacher_report_response(self, response_id: str) -> dict[str, Any]:
    """Celery entry: phụ huynh gửi phản hồi → báo giáo viên.

    Dispatch từ endpoint SAU khi commit.
    """
    db = SessionLocal()
    try:
        return _deliver_response_to_teacher(db, response_id)
    except Exception as error:
        db.rollback()
        logger.exception(
            "[ResponseNotify] Task notify_teacher lỗi (response_id=%s) — thử lại",
            response_id,
        )
        raise self.retry(exc=error)
    finally:
        db.close()


@celery_app.task(
    bind=True,
    name="notify_parent_report_response_reply",
    max_retries=3,
    default_retry_delay=30,
)
def notify_parent_report_response_reply(self, response_id: str) -> dict[str, Any]:
    """Celery entry: giáo viên trả lời → báo phụ huynh."""
    db = SessionLocal()
    try:
        return _deliver_reply_to_parent(db, response_id)
    except Exception as error:
        db.rollback()
        logger.exception(
            "[ResponseNotify] Task notify_parent lỗi (response_id=%s) — thử lại",
            response_id,
        )
        raise self.retry(exc=error)
    finally:
        db.close()
