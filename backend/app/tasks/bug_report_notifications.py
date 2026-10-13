"""
app/tasks/bug_report_notifications.py
=====================================
Celery tasks để gửi notification cho Bug Report (B-04).

2 tasks:
    1. ``notify_admin_new_bug_report``  — Khi user gửi report MỚI → notify admin
       (email + push tới tất cả admin có device token).

    2. ``notify_user_status_changed``   — Khi admin đổi trạng thái report → notify
       user đã gửi report (email + push tới device tokens của user).

Pattern: mỗi task có 2 phần:
    - Pure function ``_deliver_*``: xử lý logic thuần, nhận db session, dễ test.
    - Celery wrapper ``notify_*``: mở DB session, gọi pure function, có retry.

Email template: subject + body đơn giản, tiếng Việt.
Push payload: ``type`` discriminator + IDs để client route tới detail screen.

Failure handling:
    - Một device token lỗi không chặn các token khác.
    - Lỗi FCM/email KHÔNG làm fail task (đã log). Trả về stats để debug.
    - Task tự retry 3 lần nếu lỗi tạm thời.
"""

from __future__ import annotations

import logging
import os
import uuid
from typing import Any

from sqlalchemy.orm import Session

from app.config import settings
from app.core.database import SessionLocal
from app.models.bug_report import BugReport, BugStatus
from app.models.device_token import DeviceToken
from app.models.user import User, UserRole
from app.services.email_service import send_test_email
from app.services.notification_service import (
    is_invalid_token,
    send_push_notification,
)
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


# ===========================================================================
# Constants
# ===========================================================================

#: FCM data payload version (để client biết format)
PUSH_DATA_VERSION = "1"

#: App base URL (cho email links tới detail screen)
APP_BASE_URL = os.getenv("APP_BASE_URL", "https://kinderlog.app")


# ===========================================================================
# Email templates
# ===========================================================================


def _build_admin_email(report: BugReport, submitter: User) -> tuple[str, str]:
    """Build (subject, body) cho email thông báo admin khi có report mới.

    Args:
        report: BugReport vừa tạo
        submitter: User đã gửi report

    Returns:
        (subject, body_plain_text)
    """
    submitter_role = (
        submitter.role.value if submitter.role else "unknown"
    )
    submitter_name = "Anonymous"
    submitter_email = "N/A"

    # Lấy email từ teacher/parent profile nếu có
    if submitter.teacher is not None:
        submitter_name = submitter.teacher.full_name
        submitter_email = submitter.teacher.email
    elif submitter.parent is not None:
        submitter_name = submitter.parent.full_name or submitter.parent.email
        submitter_email = submitter.parent.email
    elif submitter.username:
        submitter_name = submitter.username

    subject = f"[KinderLog] Bug Report moi: {report.title!r}"

    body = (
        f"Xin chao Admin,\n\n"
        f"Co mot bug report moi tu nguoi dung:\n\n"
        f"  - Tieu de: {report.title}\n"
        f"  - Muc do:   {report.severity.value}\n"
        f"  - Loai:    {report.category.value}\n"
        f"  - Nguoi gui: {submitter_name} ({submitter_email}, role={submitter_role})\n"
        f"  - App version: {report.app_version or 'N/A'}\n"
        f"  - Device: {report.device_model or 'N/A'} ({report.os_version or 'N/A'})\n"
        f"  - Network: {report.network_type or 'N/A'}\n"
        f"  - Ngay gui: {report.created_at.isoformat() if report.created_at else 'N/A'}\n\n"
        f"--- Mo ta ---\n"
        f"{report.description}\n\n"
        f"--- Xem chi tiet ---\n"
        f"{APP_BASE_URL}/admin/bug-reports/{report.bug_report_id}\n\n"
        f"--- Bug report ID ---\n"
        f"{report.bug_report_id}\n\n"
        f"KinderLog System\n"
    )
    return subject, body


def _build_user_email(
    report: BugReport,
    submitter: User,
    old_status: BugStatus | None,
    new_status: BugStatus,
    admin_comment: str | None,
    admin_name: str,
) -> tuple[str, str]:
    """Build (subject, body) cho email thông báo user khi admin đổi status.

    Args:
        report: BugReport
        submitter: User đã gửi report
        old_status: Trạng thái cũ
        new_status: Trạng thái mới
        admin_comment: Ghi chú của admin (nếu có)
        admin_name: Tên admin đã xử lý

    Returns:
        (subject, body_plain_text)
    """
    submitter_email = None
    if submitter.teacher is not None:
        submitter_email = submitter.teacher.email
    elif submitter.parent is not None:
        submitter_email = submitter.parent.email

    # Nếu user không có email → trả về (None, None) để skip
    if not submitter_email:
        return "", ""

    # Map status -> tiếng Việt thân thiện
    status_vi = {
        BugStatus.OPEN: "Moi tiep nhan",
        BugStatus.IN_PROGRESS: "Dang xu ly",
        BugStatus.RESOLVED: "Da giai quyet",
        BugStatus.CLOSED: "Da dong",
        BugStatus.WONT_FIX: "Se khong sua",
    }
    old_vi = status_vi.get(old_status, "?") if old_status else "?"
    new_vi = status_vi.get(new_status, "?")

    subject = f"[KinderLog] Bug report cua ban: {new_vi}"

    body = (
        f"Xin chao,\n\n"
        f"Bug report cua ban da duoc cap nhat boi {admin_name}:\n\n"
        f"  - Tieu de: {report.title}\n"
        f"  - Trang thai cu: {old_vi}\n"
        f"  - Trang thai moi: {new_vi}\n"
        f"  - Ngay cap nhat: {report.updated_at.isoformat() if report.updated_at else 'N/A'}\n\n"
    )
    if admin_comment:
        body += (
            f"--- Ghi chu tu admin ---\n"
            f"{admin_comment}\n\n"
        )
    body += (
        f"--- Mo ta ban dau ---\n"
        f"{report.description}\n\n"
        f"--- Xem chi tiet ---\n"
        f"{APP_BASE_URL}/bug-reports/{report.bug_report_id}\n\n"
        f"Cam on ban da gop phan cai thien KinderLog!\n"
        f"KinderLog Team\n"
    )
    return subject, body


# ===========================================================================
# Helpers
# ===========================================================================


def _get_admin_emails(db: Session) -> list[str]:
    """Lấy danh sách email của tất cả admin.

    Priority:
        1. ``settings.bug_report_notify_email`` (nếu được set)
        2. Tất cả User.role=ADMIN có Teacher/Parent profile → lấy email
    """
    # 1. Config-based override
    if settings.bug_report_notify_email:
        emails = [
            e.strip()
            for e in settings.bug_report_notify_email.split(",")
            if e.strip()
        ]
        if emails:
            return emails

    # 2. Auto-detect từ admin users
    emails: list[str] = []
    admins = (
        db.query(User)
        .filter(User.role == UserRole.ADMIN, User.status == "active")
        .all()
    )
    for admin in admins:
        if admin.teacher is not None and admin.teacher.email:
            emails.append(admin.teacher.email)
        elif admin.parent is not None and admin.parent.email:
            emails.append(admin.parent.email)
    return emails


def _get_admin_device_tokens(db: Session) -> list[DeviceToken]:
    """Lấy tất cả device tokens của admin users."""
    return (
        db.query(DeviceToken)
        .join(User, DeviceToken.user_id == User.user_id)
        .filter(User.role == UserRole.ADMIN)
        .all()
    )


def _get_user_device_tokens(db: Session, user_id: uuid.UUID) -> list[DeviceToken]:
    """Lấy tất cả device tokens của 1 user."""
    return (
        db.query(DeviceToken)
        .filter(DeviceToken.user_id == user_id)
        .all()
    )


def _send_emails(emails: list[str], subject: str, body: str) -> dict[str, Any]:
    """Gửi email cho nhiều người; trả về thống kê.

    Skip email rỗng, lỗi 1 email không chặn các email khác.
    """
    if not emails or not subject:
        return {"sent": 0, "failed": 0, "skipped": len(emails) if emails else 0}

    sent = 0
    failed = 0
    for email in emails:
        if not email:
            continue
        try:
            send_test_email(to_email=email, subject=subject, body=body)
            sent += 1
        except Exception:
            failed += 1
            logger.exception(
                "[bug-notify] Gui email that bai cho %s", email
            )
    return {"sent": sent, "failed": failed, "skipped": 0}


def _send_pushes(
    tokens: list[DeviceToken],
    title: str,
    body: str,
    data: dict[str, str],
    db: Session,
) -> dict[str, Any]:
    """Gửi push tới nhiều device tokens; tự xoá invalid token.

    Returns:
        {"sent": int, "removed": int, "failed": int}
    """
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
            )
            sent += 1
        except Exception as error:
            if is_invalid_token(error):
                db.delete(device_token)
                removed += 1
                logger.info(
                    "[bug-notify] Da xoa token khong hop le: %s", device_token.token
                )
            else:
                failed += 1
                logger.exception(
                    "[bug-notify] Push that bai cho token=%s", device_token.token
                )
    if removed:
        db.commit()
    return {"sent": sent, "removed": removed, "failed": failed}


# ===========================================================================
# 1) Pure function: notify admin (khi có report mới)
# ===========================================================================


def _deliver_admin_notification(db: Session, report_id: str) -> dict[str, Any]:
    """Thuần: gửi notification tới admin khi có bug report mới.

    Returns:
        {
            "emails_sent": int,
            "emails_failed": int,
            "push_sent": int,
            "push_removed": int,
            "push_failed": int,
            "report_found": bool,
        }
    """
    try:
        report_uuid = uuid.UUID(report_id)
    except ValueError:
        logger.warning("[bug-notify] report_id khong hop le: %s", report_id)
        return {"report_found": False, "reason": "invalid_report_id"}

    report = (
        db.query(BugReport)
        .filter(BugReport.bug_report_id == report_uuid)
        .first()
    )
    if report is None:
        logger.warning("[bug-notify] Khong tim thay report_id=%s", report_id)
        return {"report_found": False, "reason": "report_not_found"}

    submitter = (
        db.query(User)
        .filter(User.user_id == report.user_id)
        .first()
    )

    # Build email
    email_subject, email_body = _build_admin_email(report, submitter)
    admin_emails = _get_admin_emails(db)
    email_stats = _send_emails(admin_emails, email_subject, email_body)

    # Build push
    severity_emoji = {
        "critical": "[CRITICAL]",
        "high": "[HIGH]",
        "medium": "",
        "low": "",
    }
    severity_tag = severity_emoji.get(report.severity.value, "")
    push_title = f"{severity_tag} Bug report moi"
    push_body = (
        f"{report.title} "
        f"(severity: {report.severity.value})"
    )[:200]
    push_data = {
        "type": "bug_report_new",
        "version": PUSH_DATA_VERSION,
        "bug_report_id": str(report.bug_report_id),
        "severity": report.severity.value,
        "category": report.category.value,
    }

    admin_tokens = _get_admin_device_tokens(db)
    push_stats = _send_pushes(
        admin_tokens, push_title, push_body, push_data, db
    )

    result = {
        "report_found": True,
        "report_id": str(report.bug_report_id),
        "emails_sent": email_stats["sent"],
        "emails_failed": email_stats["failed"],
        "push_sent": push_stats["sent"],
        "push_removed": push_stats["removed"],
        "push_failed": push_stats["failed"],
    }
    logger.info(
        "[bug-notify] Admin notification for report_id=%s: %s",
        report.bug_report_id,
        result,
    )
    return result


# ===========================================================================
# 2) Pure function: notify user (khi admin đổi status)
# ===========================================================================


def _deliver_user_notification(
    db: Session,
    report_id: str,
    old_status_value: str | None,
    new_status_value: str,
    admin_comment: str | None,
    admin_user_id: str,
) -> dict[str, Any]:
    """Thuần: gửi notification tới user khi admin đổi status report.

    Args:
        db: SQLAlchemy session
        report_id: UUID string của report
        old_status_value: Status cũ (string), None nếu là tạo mới
        new_status_value: Status mới (string)
        admin_comment: Ghi chú admin (optional)
        admin_user_id: UUID string của admin đã thực hiện thay đổi

    Returns:
        {
            "report_found": bool,
            "emails_sent": int,
            "emails_failed": int,
            "push_sent": int,
            "push_removed": int,
            "push_failed": int,
        }
    """
    try:
        report_uuid = uuid.UUID(report_id)
        admin_uuid = uuid.UUID(admin_user_id)
    except ValueError:
        logger.warning(
            "[bug-notify] report_id hoac admin_user_id khong hop le: %s / %s",
            report_id,
            admin_user_id,
        )
        return {"report_found": False, "reason": "invalid_id"}

    report = (
        db.query(BugReport)
        .filter(BugReport.bug_report_id == report_uuid)
        .first()
    )
    if report is None:
        logger.warning(
            "[bug-notify] Khong tim thay report_id=%s (user notify)", report_id
        )
        return {"report_found": False, "reason": "report_not_found"}

    submitter = (
        db.query(User)
        .filter(User.user_id == report.user_id)
        .first()
    )
    if submitter is None:
        logger.warning(
            "[bug-notify] Khong tim thay submitter (user_id=%s) cho report_id=%s",
            report.user_id,
            report_id,
        )
        return {"report_found": True, "reason": "no_submitter"}

    admin = (
        db.query(User)
        .filter(User.user_id == admin_uuid)
        .first()
    )
    admin_name = "Admin"
    if admin is not None:
        if admin.teacher is not None:
            admin_name = admin.teacher.full_name
        elif admin.parent is not None:
            admin_name = admin.parent.full_name or admin.username
        elif admin.username:
            admin_name = admin.username

    # Parse status
    try:
        old_status = (
            BugStatus(old_status_value) if old_status_value else None
        )
    except ValueError:
        logger.warning(
            "[bug-notify] old_status khong hop le: %s", old_status_value
        )
        old_status = None

    try:
        new_status = BugStatus(new_status_value)
    except ValueError as exc:
        logger.exception(
            "[bug-notify] new_status khong hop le: %s", new_status_value
        )
        return {"report_found": True, "reason": f"invalid_new_status: {exc}"}

    # Email
    email_subject, email_body = _build_user_email(
        report, submitter, old_status, new_status, admin_comment, admin_name
    )
    user_emails: list[str] = []
    if submitter.teacher is not None and submitter.teacher.email:
        user_emails.append(submitter.teacher.email)
    elif submitter.parent is not None and submitter.parent.email:
        user_emails.append(submitter.parent.email)

    email_stats = _send_emails(user_emails, email_subject, email_body)

    # Push
    status_label = {
        "open": "Moi tiep nhan",
        "in_progress": "Dang xu ly",
        "resolved": "Da giai quyet",
        "closed": "Da dong",
        "wont_fix": "Se khong sua",
    }.get(new_status.value, new_status.value)

    push_title = f"Bug report: {status_label}"
    push_body = f"{report.title}"[:200]
    push_data = {
        "type": "bug_report_updated",
        "version": PUSH_DATA_VERSION,
        "bug_report_id": str(report.bug_report_id),
        "old_status": old_status.value if old_status else "",
        "new_status": new_status.value,
        "admin_comment": admin_comment or "",
    }

    user_tokens = _get_user_device_tokens(db, submitter.user_id)
    push_stats = _send_pushes(
        user_tokens, push_title, push_body, push_data, db
    )

    result = {
        "report_found": True,
        "user_id": str(submitter.user_id),
        "emails_sent": email_stats["sent"],
        "emails_failed": email_stats["failed"],
        "push_sent": push_stats["sent"],
        "push_removed": push_stats["removed"],
        "push_failed": push_stats["failed"],
    }
    logger.info(
        "[bug-notify] User notification for report_id=%s: %s",
        report.bug_report_id,
        result,
    )
    return result


# ===========================================================================
# 3) Celery tasks (wrappers)
# ===========================================================================


@celery_app.task(
    bind=True,
    name="bug_report_notify_admin",
    max_retries=3,
    default_retry_delay=30,
)
def notify_admin_new_bug_report(self, report_id: str) -> dict[str, Any]:
    """Celery entry: gửi notification tới admin khi có report mới.

    Dispatch từ endpoint ``POST /api/bug-reports`` SAU khi commit.
    """
    db = SessionLocal()
    try:
        return _deliver_admin_notification(db, report_id)
    except Exception as error:
        db.rollback()
        logger.exception(
            "[bug-notify] Task notify_admin loi (report_id=%s) — thu lai",
            report_id,
        )
        raise self.retry(exc=error)
    finally:
        db.close()


@celery_app.task(
    bind=True,
    name="bug_report_notify_user",
    max_retries=3,
    default_retry_delay=30,
)
def notify_user_status_changed(
    self,
    report_id: str,
    old_status: str | None,
    new_status: str,
    admin_comment: str | None,
    admin_user_id: str,
) -> dict[str, Any]:
    """Celery entry: gửi notification tới user khi admin đổi status.

    Dispatch từ endpoint ``PATCH /api/bug-reports/{id}`` SAU khi commit.

    Args:
        report_id: UUID string
        old_status: Status cũ (string value)
        new_status: Status mới (string value)
        admin_comment: Ghi chú admin (optional)
        admin_user_id: UUID string của admin
    """
    db = SessionLocal()
    try:
        return _deliver_user_notification(
            db,
            report_id=report_id,
            old_status_value=old_status,
            new_status_value=new_status,
            admin_comment=admin_comment,
            admin_user_id=admin_user_id,
        )
    except Exception as error:
        db.rollback()
        logger.exception(
            "[bug-notify] Task notify_user loi (report_id=%s) — thu lai",
            report_id,
        )
        raise self.retry(exc=error)
    finally:
        db.close()
