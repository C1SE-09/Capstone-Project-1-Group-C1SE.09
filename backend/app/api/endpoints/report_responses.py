"""
app/api/endpoints/report_responses.py
======================================
REST API cho "Phản hồi báo cáo" — phụ huynh viết phản hồi ngay dưới báo
cáo hằng ngày đã gửi (kiểu bình luận phẳng, không cây reply lồng nhau).

Endpoints
---------
    POST   /api/report-responses/reports/{report_id}          Tạo phản hồi (parent)
    GET    /api/report-responses/reports/{report_id}          Danh sách phản hồi
    POST   /api/report-responses/{response_id}/resolve        Đánh dấu đã xử lý
    POST   /api/report-responses/attachments                  Upload ảnh (parent)
    GET    /api/report-responses/attachments/{child_id}/{attachment_id}  Đọc ảnh

Phân quyền
----------
- **Parent**: chỉ phản hồi được báo cáo của bé mình (quan hệ N-N
  ``parent_child`` + FK trực tiếp) → dùng ``resolve_child_for_actor``.
- **Teacher**: chỉ thấy/trả lời báo cáo của lớp mình phụ trách.
- **Admin**: thấy tất cả.

Ảnh đính kèm dùng kho MinIO **private**; đường dẫn lưu trong DB chỉ là đường
dẫn nội bộ, bytes được đọc qua endpoint ``/attachments/...`` có kiểm tra
quyền — không bao giờ trả URL công khai cho client.
"""

from __future__ import annotations

import logging
import threading
import uuid

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Response,
    UploadFile,
    status,
)
from sqlalchemy.orm import Session

from app.core.access import resolve_child_for_actor, role_of
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ParentChild
from app.models.report import DailyReport
from app.models.report_response import ReportResponse, ResponseAuthorRole
from app.models.user import User
from app.schemas.report_response import (
    ReportResponseCreateRequest,
    ReportResponseCreateResponse,
    ReportResponseListResponse,
    ReportResponseOut,
    ReportResponseResolveRequest,
    ReportResponseResolveResponse,
)
from app.services import report_response_attachments as attachments
from app.services.report_response_service import (
    count_unread_from_parent,
    create_response,
    ensure_report_responsed,
    list_responses,
    mark_all_read,
    set_resolved,
    to_dict,
)
from app.tasks.report_response_notifications import (
    notify_parent_report_response_reply,
    notify_teacher_report_response,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/report-responses", tags=["report-responses"])


# ===========================================================================
# Helpers
# ===========================================================================


def _safe_dispatch(dispatch_fn, *args, **kwargs) -> None:
    """Dispatch Celery task mà KHÔNG BAO GIỜ block request.

    Chạy trong thread daemon (fire-and-forget): request trả về ngay, lỗi
    Redis/broker chỉ được log — không ảnh hưởng thao tác của người dùng.
    """
    task_name = getattr(dispatch_fn, "name", dispatch_fn.__name__)

    def _run():
        try:
            dispatch_fn(*args, **kwargs)
        except Exception:
            logger.exception(
                "[report-responses-api] Failed to dispatch Celery task %s", task_name
            )

    threading.Thread(target=_run, daemon=True, name=f"celery-{task_name}").start()


def _teacher_owns_report(db: Session, report: DailyReport, user: User) -> bool:
    """Giáo viên có phụ trách báo cáo này không (dùng class_id của bé)."""
    if role_of(user) == "admin":
        return True
    teacher = getattr(user, "teacher", None)
    if teacher is None:
        return False
    if report.teacher_id and report.teacher_id == teacher.teacher_id:
        return True
    if report.child_id is None:
        return False
    child = db.query(Child).filter(Child.child_id == report.child_id).first()
    return bool(child and child.class_id and teacher.class_id == child.class_id)


def _ensure_can_read_report(db: Session, report: DailyReport, user: User) -> None:
    """Đảm bảo user có quyền xem phản hồi của báo cáo này."""
    role = role_of(user)
    if role == "admin":
        return
    if role == "parent":
        if report.child_id is None:
            raise HTTPException(status_code=404, detail="Không tìm thấy báo cáo")
        # resolve_child_for_actor ném 403 nếu phụ huynh không phải của bé.
        resolve_child_for_actor(db, report.child_id, user)
        return
    if role == "teacher":
        if not _teacher_owns_report(db, report, user):
            raise HTTPException(
                status_code=403,
                detail="Bạn không có quyền truy cập phản hồi của báo cáo này",
            )
        return
    raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập")


def _ensure_parent_can_post(db: Session, report: DailyReport, user: User) -> None:
    """Chỉ phụ huynh mới được gửi phản hồi mới (không phải giáo viên)."""
    if role_of(user) != "parent":
        raise HTTPException(
            status_code=403,
            detail="Chỉ phụ huynh mới có thể gửi phản hồi về báo cáo",
        )
    if report.child_id is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy báo cáo")
    resolve_child_for_actor(db, report.child_id, user)


def _parent_ids_for_child(db: Session, child_id: uuid.UUID) -> list[uuid.UUID]:
    """Danh sách parent_id liên kết với bé (N-N + FK trực tiếp)."""
    parent_ids = [
        pid
        for (pid,) in db.query(ParentChild.parent_id)
        .filter(ParentChild.child_id == child_id)
        .all()
    ]
    direct = db.query(Child.parent_id).filter(Child.child_id == child_id).scalar()
    if direct and direct not in parent_ids:
        parent_ids.append(direct)
    return parent_ids


# ===========================================================================
# 1) POST /api/report-responses/reports/{report_id}  — tạo phản hồi
# ===========================================================================


@router.post(
    "/reports/{report_id}",
    response_model=ReportResponseCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Phụ huynh gửi phản hồi về báo cáo",
    description=(
        "Tạo 1 tin nhắn phản hồi dưới báo cáo đã gửi cho phụ huynh. "
        "Danh sách phản hồi là phẳng (không reply lồng nhau). "
        "Sau khi commit, một push notification được gửi tới giáo viên."
    ),
)
def create_report_response(
    report_id: uuid.UUID,
    payload: ReportResponseCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = ensure_report_responsed(db, report_id)
    _ensure_parent_can_post(db, report, current_user)

    response = create_response(
        db,
        report=report,
        author=current_user,
        content=payload.content,
        author_role=ResponseAuthorRole.PARENT.value,
    )

    # Thông báo SAU commit — lỗi provider không được làm hỏng thao tác.
    _safe_dispatch(notify_teacher_report_response, str(response.response_id))

    return ReportResponseCreateResponse(
        response=ReportResponseOut(**to_dict(response)),
        total=len(list_responses(db, report_id)),
        unread_count=count_unread_from_parent(db, report_id),
    )


# ===========================================================================
# 2) POST /api/report-responses/reports/{report_id} (multipart) — kèm ảnh
# ===========================================================================


@router.post(
    "/reports/{report_id}/with-image",
    response_model=ReportResponseCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Phụ huynh gửi phản hồi kèm ảnh đính kèm",
    description=(
        "Giống endpoint trên nhưng nhận multipart/form-data để kèm tối đa "
        "1 ảnh (JPEG/PNG/WebP, tối đa 5 MiB). Ảnh lưu trong kho private; "
        "client đọc qua endpoint /attachments/... có kiểm tra quyền."
    ),
)
def create_report_response_with_image(
    report_id: uuid.UUID,
    content: str = Form(..., description="Nội dung phản hồi"),
    file: UploadFile | None = File(None, description="Ảnh đính kèm (tuỳ chọn)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = ensure_report_responsed(db, report_id)
    _ensure_parent_can_post(db, report, current_user)

    if report.child_id is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy báo cáo")

    image_url: str | None = None
    if file is not None and file.filename:
        image_url = attachments.save_attachment(
            child_id=report.child_id,
            user_id=current_user.user_id,
            data=file.file.read(attachments.MAX_IMAGE_BYTES + 1),
            content_type=file.content_type,
        )

    response = create_response(
        db,
        report=report,
        author=current_user,
        content=content,
        image_url=image_url,
        author_role=ResponseAuthorRole.PARENT.value,
    )

    _safe_dispatch(notify_teacher_report_response, str(response.response_id))

    return ReportResponseCreateResponse(
        response=ReportResponseOut(**to_dict(response)),
        total=len(list_responses(db, report_id)),
        unread_count=count_unread_from_parent(db, report_id),
    )


# ===========================================================================
# 2b) POST .../reply — giáo viên trả lời phản hồi của phụ huynh
# ===========================================================================


@router.post(
    "/reports/{report_id}/reply",
    response_model=ReportResponseCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Giáo viên trả lời phản hồi của phụ huynh",
    description=(
        "Giáo viên (hoặc admin) gửi 1 tin nhắn trả lời trong cùng danh sách "
        "phản hồi của báo cáo. Vì danh sách phẳng, tin nhắn của giáo viên và "
        "phụ huynh nằm chung, phân biệt bằng trường author_role."
    ),
)
def reply_report_response(
    report_id: uuid.UUID,
    payload: ReportResponseCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = (
        db.query(DailyReport)
        .filter(DailyReport.daily_report_id == report_id)
        .first()
    )
    if report is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy báo cáo")

    role = role_of(current_user)
    if role not in {"teacher", "admin"}:
        raise HTTPException(
            status_code=403, detail="Chỉ giáo viên mới có thể trả lời phản hồi"
        )
    _ensure_can_read_report(db, report, current_user)

    response = create_response(
        db,
        report=report,
        author=current_user,
        content=payload.content,
        author_role=(
            ResponseAuthorRole.TEACHER.value
            if role == "teacher"
            else ResponseAuthorRole.ADMIN.value
        ),
    )

    _safe_dispatch(notify_parent_report_response_reply, str(response.response_id))

    return ReportResponseCreateResponse(
        response=ReportResponseOut(**to_dict(response)),
        total=len(list_responses(db, report_id)),
        unread_count=count_unread_from_parent(db, report_id),
    )


# ===========================================================================
# 3) GET /api/report-responses/reports/{report_id} — danh sách phản hồi
# ===========================================================================

@router.get(
    "/reports/{report_id}",
    response_model=ReportResponseListResponse,
    summary="Danh sách phản hồi của báo cáo",
    description=(
        "Trả về toàn bộ phản hồi của báo cáo (phẳng, cũ → mới) kèm số phản hồi "
        "chưa đọc. Khi giáo viên/admin mở danh sách → các phản hồi của phụ huynh "
        "được đánh dấu đã đọc (trừ khi pass_mark_read=false)."
    ),
)
def get_report_responses(
    report_id: uuid.UUID,
    mark_read: bool = True,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = (
        db.query(DailyReport)
        .filter(DailyReport.daily_report_id == report_id)
        .first()
    )
    if report is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy báo cáo")

    _ensure_can_read_report(db, report, current_user)

    # Chỉ giáo viên/admin mới "đọc" được phản hồi của phụ huynh.
    if mark_read and role_of(current_user) in {"teacher", "admin"}:
        try:
            mark_all_read(db, report_id)
        except Exception:
            db.rollback()
            logger.exception(
                "[report-responses-api] Không đánh dấu đọc được (report_id=%s)", report_id
            )

    responses = list_responses(db, report_id)
    return ReportResponseListResponse(
        daily_report_id=report_id,
        total=len(responses),
        unread_count=count_unread_from_parent(db, report_id),
        responses=[ReportResponseOut(**to_dict(r)) for r in responses],
    )


# ===========================================================================
# 4) POST /api/report-responses/{response_id}/resolve — đánh dấu đã xử lý
# ===========================================================================


@router.post(
    "/{response_id}/resolve",
    response_model=ReportResponseResolveResponse,
    summary="Đánh dấu phản hồi đã xử lý",
    description="Giáo viên (hoặc admin) đánh dấu 1 phản hồi đã được xử lý.",
)
def resolve_report_response(
    response_id: uuid.UUID,
    payload: ReportResponseResolveRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    response = (
        db.query(ReportResponse)
        .filter(ReportResponse.response_id == response_id)
        .first()
    )
    if response is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy phản hồi")

    report = response.daily_report
    if report is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy báo cáo")

    role = role_of(current_user)
    if role not in {"teacher", "admin"}:
        raise HTTPException(
            status_code=403, detail="Chỉ giáo viên mới được đánh dấu đã xử lý"
        )
    _ensure_can_read_report(db, report, current_user)

    updated = set_resolved(
        db, response=response, actor=current_user, resolved=payload.resolved
    )
    return ReportResponseResolveResponse(
        response=ReportResponseOut(**to_dict(updated)),
        message=(
            "Đã đánh dấu phản hồi là xử lý xong"
            if payload.resolved
            else "Đã huỷ đánh dấu xử lý"
        ),
    )


# ===========================================================================
# 5) Ảnh đính kèm
# ===========================================================================


@router.post(
    "/attachments",
    summary="Upload ảnh cho phản hồi (trả về đường dẫn nội bộ)",
    status_code=status.HTTP_201_CREATED,
)
def upload_report_response_attachment(
    child_id: uuid.UUID = Form(..., description="UUID của bé"),
    file: UploadFile = File(..., description="Ảnh (JPEG/PNG/WebP, tối đa 5 MiB)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload ảnh trước khi tạo phản hồi (luồng 2 bước).

    Trả về đường dẫn NỘI BỘ dạng ``/api/report-responses/attachments/{child_id}/{id}`` —
    client dùng đường dẫn này để đọc ảnh (backend kiểm tra quyền khi đọc).
    """
    _ensure_parent_can_post_for_child(db, child_id, current_user)
    path = attachments.save_attachment(
        child_id=child_id,
        user_id=current_user.user_id,
        data=file.file.read(attachments.MAX_IMAGE_BYTES + 1),
        content_type=file.content_type,
    )
    return {"image_url": path}


def _ensure_parent_can_post_for_child(
    db: Session, child_id: uuid.UUID, user: User
) -> None:
    """Phụ huynh được upload ảnh cho bé mình; giáo viên của lớp cũng được."""
    role = role_of(user)
    if role == "parent":
        resolve_child_for_actor(db, child_id, user)
        return
    if role == "teacher":
        teacher = getattr(user, "teacher", None)
        child = db.query(Child).filter(Child.child_id == child_id).first()
        if child is None:
            raise HTTPException(status_code=404, detail="Không tìm thấy hồ sơ bé")
        if not (teacher and child.class_id and teacher.class_id == child.class_id):
            raise HTTPException(
                status_code=403, detail="Bạn không có quyền với hồ sơ bé này"
            )
        return
    if role == "admin":
        return
    raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập")


@router.get(
    "/attachments/{child_id}/{attachment_id}",
    summary="Đọc ảnh đính kèm của phản hồi",
)
def get_report_response_attachment(
    child_id: uuid.UUID,
    attachment_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Trả về bytes ảnh. Quyền đọc = quyền xem hồ sơ bé (parent/teacher/admin)."""
    role = role_of(current_user)
    if role == "parent":
        resolve_child_for_actor(db, child_id, current_user)
    elif role == "teacher":
        teacher = getattr(current_user, "teacher", None)
        child = db.query(Child).filter(Child.child_id == child_id).first()
        if child is None:
            raise HTTPException(status_code=404, detail="Không tìm thấy hồ sơ bé")
        if not (teacher and child.class_id and teacher.class_id == child.class_id):
            raise HTTPException(
                status_code=403, detail="Bạn không có quyền với hồ sơ bé này"
            )
    elif role != "admin":
        raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập")

    data, content_type = attachments.read_attachment(
        child_id=child_id, attachment_id=attachment_id
    )
    return Response(
        content=data,
        media_type=content_type,
        headers={
            "Cache-Control": "private, no-store",
            "X-Content-Type-Options": "nosniff",
        },
    )
