"""
app/api/endpoints/bug_reports.py
================================
REST API endpoints cho Bug Report (TASK: B-03 + B-04).

5 endpoints:
    POST   /api/bug-reports                   Create new bug report (any user)
    GET    /api/bug-reports                   List ALL bug reports (web admin only)
    GET    /api/bug-reports/stats             Dashboard stats (web admin only)
    GET    /api/bug-reports/{id}              Get bug report detail (web admin only)
    PATCH  /api/bug-reports/{id}              Update status / assignee / category / severity (web admin only)

Authentication: Bearer JWT
- User (teacher/parent/admin nhà trường) dùng token từ /api/auth/login
- Web Admin dùng token từ /api/admin-auth/login
Rate limit: 10 reports / user / hour (enforced in service layer)
Notification: Celery task dispatched SAU khi commit (không block API response)
    - create → notify_admin_new_bug_report
    - update_status → notify_user_status_changed
"""

from __future__ import annotations

import logging
import threading
import uuid
from typing import Annotated, Any

from app.core.admin_security import get_current_admin
from app.core.database import get_db
from app.core.security import require_any_role
from app.models.admin_user import AdminUser
from app.models.user import User
from app.schemas.bug_report import (
    BugReportCreate,
    BugReportDetail,
    BugReportListResponse,
    BugReportOut,
    BugReportUpdate,
    bug_report_to_detail,
    bug_report_to_out,
)
from app.services.bug_report_service import (
    BugReportError,
    create_report,
    get_report,
    list_reports,
    update_status,
)
from app.tasks.bug_report_notifications import (
    notify_admin_new_bug_report,
    notify_user_status_changed,
)
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


# ===========================================================================
# Router
# ===========================================================================

router = APIRouter(prefix="/api/bug-reports", tags=["bug-reports"])


# ===========================================================================
# Helper: convert BugReportError -> HTTPException
# ===========================================================================


def _http_from_bug_error(exc: BugReportError) -> HTTPException:
    """Map service-level exception sang HTTPException."""
    return HTTPException(status_code=exc.status_code, detail=exc.message)


def _safe_dispatch_celery(dispatch_fn, *args, **kwargs) -> None:
    """Dispatch Celery task mà KHÔNG BAO GIỜ block request.

    Quan trọng: chạy trong 1 thread daemon (fire-and-forget) để:
    - Request trả về NGAY, không đợi Celery acknowledge từ broker
    - Nếu Redis/broker chết → log warning, KHÔNG ảnh hưởng user

    Lỗi dispatch (Redis down, broker connection error, etc.) chỉ được log.

    Args:
        dispatch_fn: Hàm Celery, ví dụ: ``notify_admin_new_bug_report.delay``
        *args, **kwargs: Args truyền vào dispatch_fn
    """
    task_name = getattr(dispatch_fn, "name", dispatch_fn.__name__)

    def _run():
        try:
            dispatch_fn(*args, **kwargs)
        except Exception:
            logger.exception(
                "[bug-reports-api] Failed to dispatch Celery task %s",
                task_name,
            )

    thread = threading.Thread(target=_run, daemon=True, name=f"celery-{task_name}")
    thread.start()


# ===========================================================================
# 1) POST /api/bug-reports  (create)
# ===========================================================================


@router.post(
    "",
    response_model=BugReportDetail,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new bug report",
    description=(
        "Gửi bug report mới. Form fields: title, description, category, severity, "
        "app_version, build_number, os_version, device_model, network_type. "
        "Optional: tối đa 5 file ảnh (image/*), mỗi file ≤ 5MB. "
        "Rate limit: 10 reports / user / giờ."
    ),
)
async def create_bug_report(
    title: Annotated[str, Form(min_length=1, max_length=200)],
    description: Annotated[str, Form(min_length=1, max_length=4000)],
    category: Annotated[str, Form()] = "other",
    severity: Annotated[str, Form()] = "medium",
    app_version: Annotated[str | None, Form()] = None,
    build_number: Annotated[str | None, Form()] = None,
    os_version: Annotated[str | None, Form()] = None,
    device_model: Annotated[str | None, Form()] = None,
    network_type: Annotated[str | None, Form()] = None,
    attachments: Annotated[list[UploadFile] | None, File()] = None,
    current_user: User = Depends(require_any_role("teacher", "parent", "admin")),
    db: Session = Depends(get_db),
) -> BugReportDetail:
    """Tạo bug report mới.

    Endpoint này dùng multipart/form-data vì có file uploads. Nếu không có file,
    vẫn phải dùng multipart (form-encoded). JSON body không hỗ trợ file.
    """
    # Build payload dict (giống BugReportCreate)
    payload: dict[str, Any] = {
        "title": title.strip(),
        "description": description.strip(),
        "category": category,
        "severity": severity,
        "app_version": app_version,
        "build_number": build_number,
        "os_version": os_version,
        "device_model": device_model,
        "network_type": network_type,
    }

    # Validate qua Pydantic schema trước khi vào service
    try:
        validated = BugReportCreate(**payload)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Validation error: {exc}",
        ) from exc

    # Đọc attachments
    attachment_payloads: list[dict[str, Any]] = []
    if attachments:
        for f in attachments:
            data = await f.read()
            if not data:
                continue
            attachment_payloads.append(
                {
                    "file_data": data,
                    "file_name": f.filename or "unnamed",
                    "mime_type": f.content_type or "application/octet-stream",
                }
            )

    # Gọi service
    try:
        report, _used, _reset_at = create_report(
            db=db,
            user=current_user,
            data=validated.model_dump(),
            attachments=attachment_payloads,
        )
    except BugReportError as exc:
        raise _http_from_bug_error(exc) from exc

    # Reload để có đầy đủ relationships (user, attachments, history)
    report = get_report(db, report.bug_report_id, current_user)

    # B-04: Dispatch Celery task để notify admin (email + push).
    # Lỗi dispatch KHÔNG làm fail request.
    _safe_dispatch_celery(
        notify_admin_new_bug_report.delay,
        str(report.bug_report_id),
    )

    return BugReportDetail(**bug_report_to_detail(report))


# ===========================================================================
# 1.5) GET /api/bug-reports/me  (user list own reports)
# ===========================================================================


@router.get(
    "/me",
    response_model=BugReportListResponse,
    summary="[User] List my bug reports",
    description="Danh sách các bug reports do chính người dùng hiện tại (giáo viên, phụ huynh) gửi.",
)
def user_list_my_reports(
    status_filter: Annotated[
        str | None,
        Query(
            alias="status",
            description="open | in_progress | resolved | closed | wont_fix",
        ),
    ] = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    current_user: User = Depends(require_any_role("teacher", "parent", "admin")),
    db: Session = Depends(get_db),
) -> BugReportListResponse:
    filters: dict[str, Any] = {"user_id": current_user.user_id}
    if status_filter:
        filters["status"] = status_filter
    items, total = list_reports(
        db=db,
        filters=filters,
        page=page,
        page_size=page_size,
        order_by="created_at_desc",
    )
    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    return BugReportListResponse(
        items=[BugReportOut(**bug_report_to_out(r)) for r in items],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        has_next=page < total_pages,
        has_prev=page > 1,
    )


# ===========================================================================
# 2) GET /api/bug-reports  (admin list all)
# ===========================================================================


@router.get(
    "",
    response_model=BugReportListResponse,
    summary="[Web Admin] List all bug reports",
    description=(
        "Danh sách tất cả bug reports với filter (status, severity, category, "
        "user_id, teacher_id, user_role, search, date_from, date_to) + pagination + sort."
    ),
)
def admin_list_bug_reports(
    status_filter: Annotated[
        str | None,
        Query(
            alias="status",
            description="open | in_progress | resolved | closed | wont_fix",
        ),
    ] = None,
    severity: Annotated[
        str | None,
        Query(description="low | medium | high | critical"),
    ] = None,
    category: Annotated[
        str | None,
        Query(
            description="ui | performance | crash | data | notification | network | auth | other"
        ),
    ] = None,
    user_id: Annotated[uuid.UUID | None, Query()] = None,
    teacher_id: Annotated[uuid.UUID | None, Query()] = None,
    user_role: Annotated[
        str | None,
        Query(description="teacher | parent | admin"),
    ] = None,
    search: Annotated[str | None, Query(max_length=200)] = None,
    date_from: Annotated[
        str | None,
        Query(description="ISO datetime (UTC), vd: 2026-10-12T00:00:00"),
    ] = None,
    date_to: Annotated[
        str | None,
        Query(description="ISO datetime (UTC), vd: 2026-10-12T23:59:59"),
    ] = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: Annotated[
        str,
        Query(description="created_at_desc | created_at_asc | severity_desc"),
    ] = "created_at_desc",
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> BugReportListResponse:
    """Web Admin list với filter + pagination. Tất cả fields optional."""
    from datetime import datetime

    # Build filter dict
    filters: dict[str, Any] = {}
    if status_filter:
        filters["status"] = status_filter
    if severity:
        filters["severity"] = severity
    if category:
        filters["category"] = category
    if user_id:
        filters["user_id"] = user_id
    if teacher_id:
        filters["teacher_id"] = teacher_id
    if user_role:
        filters["user_role"] = user_role
    if search:
        filters["search"] = search
    if date_from:
        try:
            filters["date_from"] = datetime.fromisoformat(date_from)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"date_from không hợp lệ: {date_from}",
            ) from exc
    if date_to:
        try:
            filters["date_to"] = datetime.fromisoformat(date_to)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"date_to không hợp lệ: {date_to}",
            ) from exc

    items, total = list_reports(
        db=db,
        filters=filters,
        page=page,
        page_size=page_size,
        order_by=order_by,
    )
    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    return BugReportListResponse(
        items=[BugReportOut(**bug_report_to_out(r)) for r in items],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        has_next=page < total_pages,
        has_prev=page > 1,
    )


# ===========================================================================
# 5) GET /api/bug-reports/{id}  (admin get detail)
# ===========================================================================


@router.get(
    "/{report_id}",
    response_model=BugReportDetail,
    summary="[Web Admin] Get bug report detail",
    description="Chi tiết 1 bug report bất kỳ (kèm attachments + history).",
)
def admin_get_bug_report(
    report_id: uuid.UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> BugReportDetail:
    try:
        report = get_report(db, report_id, current_admin)
    except BugReportError as exc:
        raise _http_from_bug_error(exc) from exc
    return BugReportDetail(**bug_report_to_detail(report))


# ===========================================================================
# 6) PATCH /api/bug-reports/{id}  (admin update)
# ===========================================================================


@router.patch(
    "/{report_id}",
    response_model=BugReportDetail,
    summary="[Web Admin] Update bug report",
    description=(
        "Web admin cập nhật status (open | in_progress | resolved | closed | wont_fix), "
        "gán teacher (teacher_id), sửa lại category / severity, hoặc thêm comment. "
        "Mọi thay đổi được ghi vào bug_report_history (audit trail)."
    ),
)
def admin_update_bug_report(
    report_id: uuid.UUID,
    payload: BugReportUpdate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> BugReportDetail:
    try:
        report = update_status(
            db=db,
            report_id=report_id,
            changed_by=current_admin,
            new_status=payload.status,
            new_teacher_id=payload.teacher_id,
            new_category=payload.category,
            new_severity=payload.severity,
            comment=payload.comment,
        )
    except BugReportError as exc:
        raise _http_from_bug_error(exc) from exc

    # Reload để có relationships
    report = get_report(db, report.bug_report_id, current_admin)

    # B-04: Dispatch Celery task để notify user (email + push).
    # Lỗi dispatch KHÔNG làm fail request.
    # Chỉ gửi notification nếu status thực sự thay đổi
    # (update_status đã no-op nếu status không đổi, nên check sau khi update).
    if payload.status is not None:
        _safe_dispatch_celery(
            notify_user_status_changed.delay,
            str(report.bug_report_id),
            None,  # old_status - lấy từ history entry cuối
            payload.status,
            payload.comment,
            str(current_admin.admin_user_id),  # actor id (web admin)
        )

    return BugReportDetail(**bug_report_to_detail(report))
