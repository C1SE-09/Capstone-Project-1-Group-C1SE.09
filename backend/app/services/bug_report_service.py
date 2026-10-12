"""
app/services/bug_report_service.py
==================================
Service layer cho Bug Report (TASK: B-02).

Business logic:
    - create_report       : tạo bug report + initial history + upload attachments
    - list_reports        : admin list với filter + pagination
    - get_report          : lấy chi tiết (kèm attachments + history)
    - get_user_reports    : list reports của 1 user
    - update_status       : admin update status/assignee + record history
    - add_attachments     : thêm attachments vào report đã tồn tại
    - check_rate_limit    : 10 reports / user / giờ (chống spam)

Side effects:
    - Upload file lên MinIO (S3-compatible storage) dùng ``app.core.storage``
    - Ghi history vào ``bug_report_history`` (audit trail)
    - Validate MIME type, file size, số lượng attachments
    - Validate permission (admin / author)

Exceptions (raised từ service, mapped sang HTTPException ở endpoint layer):
    - BugReportError
        - BugReportNotFoundError      : 404
        - BugReportPermissionError    : 403
        - BugReportRateLimitError     : 429
        - BugReportValidationError    : 400
"""

from __future__ import annotations

import io
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, BinaryIO

from app.core.storage import _ensure_bucket_exists, minio_client
from app.models.bug_report import (
    BugCategory,
    BugReport,
    BugReportAttachment,
    BugReportHistory,
    BugSeverity,
    BugStatus,
)
from app.models.user import User, UserRole
from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session, selectinload

logger = logging.getLogger(__name__)


# ===========================================================================
# Constants
# ===========================================================================


#: Max size per attachment file (5 MB)
MAX_ATTACHMENT_SIZE_BYTES: int = 5 * 1024 * 1024

#: Max total attachments per bug report
MAX_ATTACHMENTS_PER_REPORT: int = 5

#: Allowed MIME types for attachments
ALLOWED_MIME_TYPES: set[str] = {
    "image/png",
    "image/jpeg",
    "image/jpg",
    "image/webp",
    "image/gif",
    "image/heic",
    "image/heif",
    # Cho phép text log nhỏ đính kèm
    "text/plain",
    "application/json",
}

#: Rate limit: max reports per user per hour
RATE_LIMIT_REPORTS_PER_HOUR: int = 10

#: MinIO bucket cho bug report attachments
BUG_REPORT_BUCKET: str = "bug-reports"


# ===========================================================================
# Custom Exceptions
# ===========================================================================


class BugReportError(Exception):
    """Base exception cho bug report service."""

    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class BugReportNotFoundError(BugReportError):
    """Bug report không tồn tại."""

    def __init__(self, message: str = "Bug report không tồn tại"):
        super().__init__(message, status_code=404)


class BugReportPermissionError(BugReportError):
    """User không có quyền thực hiện thao tác."""

    def __init__(self, message: str = "Bạn không có quyền thực hiện thao tác này"):
        super().__init__(message, status_code=403)


class BugReportRateLimitError(BugReportError):
    """User đã gửi quá nhiều reports trong 1 giờ."""

    def __init__(self, message: str = "Bạn đã gửi quá nhiều báo cáo. Vui lòng thử lại sau."):
        super().__init__(message, status_code=429)


class BugReportValidationError(BugReportError):
    """Input không hợp lệ (file quá lớn, sai MIME, quá nhiều files...)."""

    def __init__(self, message: str = "Dữ liệu không hợp lệ"):
        super().__init__(message, status_code=400)


# ===========================================================================
# Permission helpers
# ===========================================================================


def _is_admin(user: User) -> bool:
    """True nếu user có role admin."""
    return user.role == UserRole.ADMIN


def _can_view_report(user: User, report: BugReport) -> bool:
    """User có thể xem report này không?
    - Admin: luôn được
    - User khác: chỉ xem được report do chính mình tạo
    """
    if _is_admin(user):
        return True
    return report.user_id == user.user_id


def _can_modify_report(user: User, report: BugReport) -> bool:
    """User có thể modify report này không?
    - Admin: luôn được
    - Author: được thêm attachments vào report của mình
    """
    if _is_admin(user):
        return True
    return report.user_id == user.user_id


# ===========================================================================
# Rate limit helpers
# ===========================================================================


def check_rate_limit(
    db: Session,
    user_id: uuid.UUID,
    limit: int = RATE_LIMIT_REPORTS_PER_HOUR,
    window_hours: int = 1,
) -> tuple[int, datetime]:
    """Kiểm tra rate limit cho user.

    Args:
        db: SQLAlchemy session
        user_id: UUID của user
        limit: Số report tối đa
        window_hours: Khoảng thời gian (giờ)

    Returns:
        (used_count, reset_at): số report đã gửi và thời điểm reset

    Raises:
        BugReportRateLimitError: Nếu user đã vượt quá giới hạn
    """
    now = datetime.now(timezone.utc)
    window_start = now - timedelta(hours=window_hours)

    used = (
        db.query(func.count(BugReport.bug_report_id))
        .filter(
            BugReport.user_id == user_id,
            BugReport.created_at >= window_start,
        )
        .scalar()
        or 0
    )

    if used >= limit:
        # Tính thời điểm reset = thời điểm cũ nhất trong window + window
        oldest = (
            db.query(BugReport.created_at)
            .filter(
                BugReport.user_id == user_id,
                BugReport.created_at >= window_start,
            )
            .order_by(BugReport.created_at.asc())
            .first()
        )
        reset_at = (oldest[0] + timedelta(hours=window_hours)) if oldest else now
        raise BugReportRateLimitError(
            f"Bạn đã gửi {used}/{limit} báo cáo trong {window_hours} giờ qua. "
            f"Vui lòng thử lại sau {reset_at.isoformat()}."
        )

    # reset_at = window_start + window_hours (khi nào count sẽ giảm xuống)
    reset_at = window_start + timedelta(hours=window_hours)
    return used, reset_at


# ===========================================================================
# MinIO upload helpers
# ===========================================================================


def _validate_attachment_file(
    file_data: bytes,
    file_name: str,
    mime_type: str | None,
    max_size: int = MAX_ATTACHMENT_SIZE_BYTES,
) -> None:
    """Validate file trước khi upload.

    Raises:
        BugReportValidationError: nếu file không hợp lệ
    """
    if not file_data:
        raise BugReportValidationError(f"File '{file_name}' rỗng")

    if len(file_data) > max_size:
        size_mb = len(file_data) / (1024 * 1024)
        raise BugReportValidationError(
            f"File '{file_name}' quá lớn ({size_mb:.2f} MB). "
            f"Tối đa {max_size / (1024 * 1024):.0f} MB."
        )

    if mime_type and mime_type not in ALLOWED_MIME_TYPES:
        raise BugReportValidationError(
            f"File '{file_name}' có MIME type '{mime_type}' không được phép. "
            f"Cho phép: {sorted(ALLOWED_MIME_TYPES)}"
        )


def _upload_to_minio(
    file_data: bytes,
    file_name: str,
    mime_type: str,
    user_id: uuid.UUID,
) -> str:
    """Upload file lên MinIO và trả về public URL.

    Args:
        file_data: bytes của file
        file_name: tên file gốc
        mime_type: MIME type
        user_id: UUID user upload (để tổ chức thư mục)

    Returns:
        URL công khai dạng ``http://<endpoint>/<bucket>/<object>``
    """
    # Tạo object name: bug_reports/<user_id>/<timestamp>_<safe_filename>
    safe_name = "".join(
        c if c.isalnum() or c in "._-" else "_" for c in file_name
    )[:100]
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    unique_id = uuid.uuid4().hex[:8]
    object_name = f"bug_reports/{user_id}/{timestamp}_{unique_id}_{safe_name}"

    _ensure_bucket_exists(BUG_REPORT_BUCKET)
    minio_client.put_object(
        bucket_name=BUG_REPORT_BUCKET,
        object_name=object_name,
        data=io.BytesIO(file_data),
        length=len(file_data),
        content_type=mime_type,
    )

    # Trả về URL public (dựa trên config của MinIO)
    from app.config import settings

    protocol = "https" if settings.minio_secure else "http"
    return f"{protocol}://{settings.minio_endpoint}/{BUG_REPORT_BUCKET}/{object_name}"


# ===========================================================================
# History helper
# ===========================================================================


def _record_history(
    db: Session,
    report: BugReport,
    changed_by: User,
    old_status: BugStatus | None,
    new_status: BugStatus | None,
    old_teacher_id: uuid.UUID | None,
    new_teacher_id: uuid.UUID | None,
    comment: str | None,
) -> BugReportHistory:
    """Ghi 1 entry vào bug_report_history (audit trail)."""
    entry = BugReportHistory(
        bug_report_id=report.bug_report_id,
        changed_by_id=changed_by.user_id,
        old_status=old_status,
        new_status=new_status,
        old_teacher_id=old_teacher_id,
        new_teacher_id=new_teacher_id,
        comment=comment,
    )
    db.add(entry)
    return entry


# ===========================================================================
# Public API: Create
# ===========================================================================


def create_report(
    db: Session,
    user: User,
    data: dict[str, Any],
    attachments: list[dict[str, Any]] | None = None,
) -> tuple[BugReport, int, datetime]:
    """Tạo bug report mới.

    Args:
        db: SQLAlchemy session
        user: User đang gửi report
        data: dict từ BugReportCreate schema, ví dụ:
            {
                "title": "...",
                "description": "...",
                "category": "crash",
                "severity": "high",
                "app_version": "1.2.3",
                ...
            }
        attachments: list of dict, mỗi dict có:
            {
                "file_data": bytes,
                "file_name": str,
                "mime_type": str,
            }

    Returns:
        (BugReport, used_count, reset_at)

    Raises:
        BugReportRateLimitError: nếu vượt rate limit
        BugReportValidationError: nếu file không hợp lệ
    """
    # 1. Rate limit
    used, reset_at = check_rate_limit(db, user.user_id)

    # 2. Validate attachments
    attachments = attachments or []
    if len(attachments) > MAX_ATTACHMENTS_PER_REPORT:
        raise BugReportValidationError(
            f"Tối đa {MAX_ATTACHMENTS_PER_REPORT} ảnh / bug report. "
            f"Bạn gửi {len(attachments)}."
        )

    # 3. Tạo BugReport
    category = data.get("category", "other")
    severity = data.get("severity", "medium")

    # Convert string → Enum nếu cần
    if isinstance(category, str):
        category = BugCategory(category)
    if isinstance(severity, str):
        severity = BugSeverity(severity)

    report = BugReport(
        user_id=user.user_id,
        title=data["title"].strip(),
        description=data["description"].strip(),
        category=category,
        severity=severity,
        status=BugStatus.OPEN,  # mặc định OPEN
        app_version=data.get("app_version"),
        build_number=data.get("build_number"),
        os_version=data.get("os_version"),
        device_model=data.get("device_model"),
        network_type=data.get("network_type"),
    )
    db.add(report)
    db.flush()  # lấy bug_report_id

    # 4. Ghi history entry đầu tiên (status = OPEN, không có old)
    _record_history(
        db=db,
        report=report,
        changed_by=user,
        old_status=None,
        new_status=BugStatus.OPEN,
        old_teacher_id=None,
        new_teacher_id=None,
        comment="Bug report được tạo",
    )

    # 5. Upload attachments
    for att in attachments:
        file_data: bytes = att["file_data"]
        file_name: str = att["file_name"]
        mime_type: str = att.get("mime_type") or "application/octet-stream"

        _validate_attachment_file(file_data, file_name, mime_type)
        file_url = _upload_to_minio(
            file_data=file_data,
            file_name=file_name,
            mime_type=mime_type,
            user_id=user.user_id,
        )

        attachment = BugReportAttachment(
            bug_report_id=report.bug_report_id,
            file_url=file_url,
            file_name=file_name,
            file_size=len(file_data),
            mime_type=mime_type,
            description=att.get("description"),
        )
        db.add(attachment)

    db.commit()
    db.refresh(report)

    logger.info(
        "[bug_report_service] Created report id=%s by user_id=%s with %d attachments",
        report.bug_report_id,
        user.user_id,
        len(attachments),
    )
    return report, used + 1, reset_at


# ===========================================================================
# Public API: Read
# ===========================================================================


def _build_filter_query(filters: dict[str, Any] | None = None):
    """Helper: build WHERE clause từ filter dict.

    Returns:
        list of SQLAlchemy conditions
    """
    conditions = []
    if not filters:
        return conditions

    if f := filters.get("status"):
        if isinstance(f, str):
            f = BugStatus(f)
        conditions.append(BugReport.status == f)

    if f := filters.get("severity"):
        if isinstance(f, str):
            f = BugSeverity(f)
        conditions.append(BugReport.severity == f)

    if f := filters.get("category"):
        if isinstance(f, str):
            f = BugCategory(f)
        conditions.append(BugReport.category == f)

    if f := filters.get("user_id"):
        conditions.append(BugReport.user_id == f)

    if f := filters.get("teacher_id"):
        conditions.append(BugReport.teacher_id == f)

    if f := filters.get("user_role"):
        # Join với User và filter theo role
        conditions.append(User.role == f)

    if f := filters.get("search"):
        # Case-insensitive substring search trên title
        conditions.append(BugReport.title.ilike(f"%{f}%"))

    if f := filters.get("date_from"):
        conditions.append(BugReport.created_at >= f)

    if f := filters.get("date_to"):
        conditions.append(BugReport.created_at <= f)

    return conditions


def list_reports(
    db: Session,
    filters: dict[str, Any] | None = None,
    page: int = 1,
    page_size: int = 20,
    order_by: str = "created_at_desc",
) -> tuple[list[BugReport], int]:
    """Admin list tất cả bug reports với filter + pagination.

    Args:
        db: SQLAlchemy session
        filters: dict filter (xem ``BugReportFilter``)
        page: trang hiện tại (1-indexed)
        page_size: số item / trang
        order_by: thứ tự sắp xếp:
            - "created_at_desc" (default) - mới nhất trước
            - "created_at_asc" - cũ nhất trước
            - "severity_desc" - critical trước

    Returns:
        (list[BugReport], total)
    """
    if page < 1:
        page = 1
    if page_size < 1 or page_size > 100:
        page_size = 20

    conditions = _build_filter_query(filters)

    # Build base query
    query = db.query(BugReport).join(User, BugReport.user_id == User.user_id)
    if conditions:
        query = query.filter(and_(*conditions))

    # Total count (independent query without order_by to avoid GROUP BY errors)
    count_query = db.query(func.count(BugReport.bug_report_id)).join(
        User, BugReport.user_id == User.user_id
    )
    if conditions:
        count_query = count_query.filter(and_(*conditions))
    total = count_query.scalar() or 0

    # Order by
    if order_by == "created_at_asc":
        query = query.order_by(BugReport.created_at.asc())
    elif order_by == "severity_desc":
        # Critical → High → Medium → Low
        severity_order = func.array_position(
            func.array(
                [
                    BugSeverity.CRITICAL.value,
                    BugSeverity.HIGH.value,
                    BugSeverity.MEDIUM.value,
                    BugSeverity.LOW.value,
                ]
            ),
            BugReport.severity,
        )
        query = query.order_by(severity_order.asc(), BugReport.created_at.desc())
    else:  # default created_at_desc
        query = query.order_by(BugReport.created_at.desc())

    # Eager load user + teacher
    query = query.options(
        selectinload(BugReport.user),
        selectinload(BugReport.teacher),
    )

    # Paginate
    offset = (page - 1) * page_size
    items = query.offset(offset).limit(page_size).all()

    return items, total


def get_report(
    db: Session,
    report_id: uuid.UUID,
    user: User | None = None,
) -> BugReport:
    """Lấy chi tiết 1 bug report.

    Args:
        db: SQLAlchemy session
        report_id: UUID của report
        user: User hiện tại (optional, dùng để check permission)

    Returns:
        BugReport với attachments + history đã eager load

    Raises:
        BugReportNotFoundError: nếu không tìm thấy
        BugReportPermissionError: nếu user không có quyền xem
    """
    report = (
        db.query(BugReport)
        .options(
            selectinload(BugReport.user),
            selectinload(BugReport.teacher),
            selectinload(BugReport.attachments),
            selectinload(BugReport.history).selectinload(BugReportHistory.changed_by),
        )
        .filter(BugReport.bug_report_id == report_id)
        .first()
    )
    if report is None:
        raise BugReportNotFoundError()

    if user is not None and not _can_view_report(user, report):
        raise BugReportPermissionError(
            "Bạn chỉ có thể xem report do chính mình tạo"
        )

    return report


def get_user_reports(
    db: Session,
    user_id: uuid.UUID,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[BugReport], int]:
    """List bug reports của 1 user (dùng cho endpoint ``/me``).

    Args:
        db: SQLAlchemy session
        user_id: UUID của user
        page: trang hiện tại
        page_size: số item / trang

    Returns:
        (list[BugReport], total)
    """
    if page < 1:
        page = 1
    if page_size < 1 or page_size > 100:
        page_size = 20

    query = (
        db.query(BugReport)
        .options(
            selectinload(BugReport.user),
            selectinload(BugReport.teacher),
        )
        .filter(BugReport.user_id == user_id)
        .order_by(BugReport.created_at.desc())
    )
    # Independent count query (no order_by)
    total = (
        db.query(func.count(BugReport.bug_report_id))
        .filter(BugReport.user_id == user_id)
        .scalar()
        or 0
    )

    offset = (page - 1) * page_size
    items = query.offset(offset).limit(page_size).all()
    return items, total


# ===========================================================================
# Public API: Update
# ===========================================================================


def update_status(
    db: Session,
    report_id: uuid.UUID,
    changed_by: User,
    new_status: str | BugStatus | None = None,
    new_teacher_id: uuid.UUID | None = None,
    comment: str | None = None,
) -> BugReport:
    """Admin cập nhật status / assignee cho 1 bug report.

    Mọi thay đổi đều được ghi vào bug_report_history.

    Args:
        db: SQLAlchemy session
        report_id: UUID của report
        changed_by: User thực hiện thay đổi (phải là admin)
        new_status: status mới (optional)
        new_teacher_id: teacher_id mới (optional, None = bỏ gán)
        comment: ghi chú (optional)

    Returns:
        BugReport đã update

    Raises:
        BugReportNotFoundError: nếu không tìm thấy
        BugReportPermissionError: nếu changed_by không phải admin
        BugReportValidationError: nếu new_status invalid
    """
    if not _is_admin(changed_by):
        raise BugReportPermissionError(
            "Chỉ admin mới có thể cập nhật trạng thái bug report"
        )

    report = (
        db.query(BugReport)
        .filter(BugReport.bug_report_id == report_id)
        .first()
    )
    if report is None:
        raise BugReportNotFoundError()

    # Normalize new_status
    if isinstance(new_status, str):
        try:
            new_status = BugStatus(new_status)
        except ValueError as exc:
            raise BugReportValidationError(
                f"Status '{new_status}' không hợp lệ. "
                f"Cho phép: {[s.value for s in BugStatus]}"
            ) from exc

    old_status = report.status
    old_teacher_id = report.teacher_id

    # Validate: teacher_id phải tồn tại nếu được cung cấp
    if new_teacher_id is not None:
        from app.models.user import Teacher  # tránh circular

        teacher_exists = (
            db.query(Teacher)
            .filter(Teacher.teacher_id == new_teacher_id)
            .first()
        )
        if teacher_exists is None:
            raise BugReportValidationError(
                f"Teacher với id {new_teacher_id} không tồn tại"
            )

    # Detect xem có thay đổi gì không
    status_changed = new_status is not None and new_status != old_status
    teacher_changed = new_teacher_id != old_teacher_id  # cũng cover set None

    if not status_changed and not teacher_changed:
        # Không có gì thay đổi
        logger.info(
            "[bug_report_service] update_status no-op: report_id=%s", report_id
        )
        return report

    # Update report
    if status_changed:
        report.status = new_status
        # Set resolved_at / closed_at tương ứng
        if new_status == BugStatus.RESOLVED and report.resolved_at is None:
            report.resolved_at = datetime.now(timezone.utc)
        if new_status == BugStatus.CLOSED and report.closed_at is None:
            report.closed_at = datetime.now(timezone.utc)

    if teacher_changed:
        report.teacher_id = new_teacher_id

    # Ghi history
    _record_history(
        db=db,
        report=report,
        changed_by=changed_by,
        old_status=old_status if status_changed else None,
        new_status=new_status if status_changed else None,
        old_teacher_id=old_teacher_id if teacher_changed else None,
        new_teacher_id=new_teacher_id if teacher_changed else None,
        comment=comment,
    )

    db.commit()
    db.refresh(report)

    logger.info(
        "[bug_report_service] Updated report id=%s: status=%s→%s, teacher=%s→%s by user_id=%s",
        report.bug_report_id,
        old_status.value if old_status else None,
        new_status.value if new_status else None,
        old_teacher_id,
        new_teacher_id,
        changed_by.user_id,
    )
    return report


# ===========================================================================
# Public API: Add Attachments
# ===========================================================================


def add_attachments(
    db: Session,
    report_id: uuid.UUID,
    user: User,
    attachments: list[dict[str, Any]],
) -> tuple[BugReport, list[BugReportAttachment]]:
    """Thêm attachments vào bug report đã tồn tại.

    Args:
        db: SQLAlchemy session
        report_id: UUID của report
        user: User upload (phải là author hoặc admin)
        attachments: list of dict, mỗi dict có:
            {
                "file_data": bytes,
                "file_name": str,
                "mime_type": str,
            }

    Returns:
        (BugReport, list[BugReportAttachment vừa tạo])

    Raises:
        BugReportNotFoundError, BugReportPermissionError, BugReportValidationError
    """
    report = (
        db.query(BugReport)
        .options(selectinload(BugReport.attachments))
        .filter(BugReport.bug_report_id == report_id)
        .first()
    )
    if report is None:
        raise BugReportNotFoundError()

    if not _can_modify_report(user, report):
        raise BugReportPermissionError(
            "Bạn chỉ có thể upload attachments vào report của mình"
        )

    # Validate số lượng
    current_count = len(report.attachments) if report.attachments else 0
    if current_count + len(attachments) > MAX_ATTACHMENTS_PER_REPORT:
        raise BugReportValidationError(
            f"Report đã có {current_count} attachments. "
            f"Tối đa {MAX_ATTACHMENTS_PER_REPORT}. "
            f"Bạn đang upload {len(attachments)} thêm."
        )

    new_attachments = []
    for att in attachments:
        file_data: bytes = att["file_data"]
        file_name: str = att["file_name"]
        mime_type: str = att.get("mime_type") or "application/octet-stream"

        _validate_attachment_file(file_data, file_name, mime_type)
        file_url = _upload_to_minio(
            file_data=file_data,
            file_name=file_name,
            mime_type=mime_type,
            user_id=user.user_id,
        )

        attachment = BugReportAttachment(
            bug_report_id=report.bug_report_id,
            file_url=file_url,
            file_name=file_name,
            file_size=len(file_data),
            mime_type=mime_type,
            description=att.get("description"),
        )
        db.add(attachment)
        new_attachments.append(attachment)

    db.commit()
    for att in new_attachments:
        db.refresh(att)

    logger.info(
        "[bug_report_service] Added %d attachments to report_id=%s by user_id=%s",
        len(new_attachments),
        report_id,
        user.user_id,
    )
    return report, new_attachments


# ===========================================================================
# Utility
# ===========================================================================


def get_stats(db: Session) -> dict[str, Any]:
    """Trả về thống kê số lượng reports theo status, severity, category.

    Dùng cho admin dashboard (B-07 sẽ dùng).
    """
    by_status = dict(
        db.query(BugReport.status, func.count(BugReport.bug_report_id))
        .group_by(BugReport.status)
        .all()
    )
    by_severity = dict(
        db.query(BugReport.severity, func.count(BugReport.bug_report_id))
        .group_by(BugReport.severity)
        .all()
    )
    by_category = dict(
        db.query(BugReport.category, func.count(BugReport.bug_report_id))
        .group_by(BugReport.category)
        .all()
    )
    total = db.query(func.count(BugReport.bug_report_id)).scalar() or 0

    return {
        "total": total,
        "by_status": {k.value: v for k, v in by_status.items()},
        "by_severity": {k.value: v for k, v in by_severity.items()},
        "by_category": {k.value: v for k, v in by_category.items()},
    }


# Re-export
__all__ = [
    "ALLOWED_MIME_TYPES",
    "BUG_REPORT_BUCKET",
    "MAX_ATTACHMENTS_PER_REPORT",
    "MAX_ATTACHMENT_SIZE_BYTES",
    "RATE_LIMIT_REPORTS_PER_HOUR",
    "BugCategory",
    "BugReport",
    "BugReportAttachment",
    "BugReportError",
    "BugReportHistory",
    "BugReportNotFoundError",
    "BugReportPermissionError",
    "BugReportRateLimitError",
    "BugReportValidationError",
    "BugSeverity",
    "BugStatus",
    "add_attachments",
    "check_rate_limit",
    "create_report",
    "get_report",
    "get_stats",
    "get_user_reports",
    "list_reports",
    "update_status",
]
