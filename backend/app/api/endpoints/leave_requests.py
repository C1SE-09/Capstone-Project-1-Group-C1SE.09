"""
backend/app/api/endpoints/leave_requests.py
===========================================
API đơn nghỉ/báo trễ: lịch sử phụ huynh, danh sách lớp và xét duyệt.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.access import resolve_child_for_actor, role_of
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.leave_request import LeaveRequest, LeaveRequestStatus
from app.models.user import User
from app.schemas.leave_request_schema import (
    LeaveRequestAttachmentResponse,
    LeaveRequestBatchSummary,
    LeaveRequestCreate,
    LeaveRequestPage,
    LeaveRequestReject,
    LeaveRequestResponse,
)
from app.services.leave_request_attachments import MAX_IMAGE_BYTES, read_attachment, save_attachment
from app.services.leave_request_service import (
    create_request,
    require_parent,
    review_request,
    verify_class_access,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/leave-requests", tags=["leave-requests"])


def _to_response_dto(req: LeaveRequest) -> LeaveRequestResponse:
    """Map SQLAlchemy LeaveRequest sang LeaveRequestResponse DTO."""
    child_name = req.child.full_name if req.child else None
    child_avatar_url = req.child.avatar_url if req.child else None
    parent_name = req.parent.full_name if req.parent else None
    reviewer_name = req.reviewer.full_name if req.reviewer else None

    return LeaveRequestResponse(
        request_id=req.request_id,
        child_id=req.child_id,
        parent_id=req.parent_id,
        class_id=req.class_id,
        from_date=req.from_date,
        to_date=req.to_date,
        reason=req.reason,
        attachment_url=req.attachment_url,
        request_type=req.request_type,
        expected_arrival_time=req.expected_arrival_time,
        meal_warning_acknowledged=req.meal_warning_acknowledged,
        status=req.status,
        reject_reason=req.reject_reason,
        reviewed_by=req.reviewed_by,
        reviewed_at=req.reviewed_at,
        created_at=req.created_at,
        updated_at=req.updated_at,
        child_name=child_name,
        child_avatar_url=child_avatar_url,
        parent_name=parent_name,
        reviewer_name=reviewer_name,
    )


@router.get("/class/{class_id}", response_model=LeaveRequestBatchSummary)
def get_class_leave_requests(
    class_id: uuid.UUID,
    tab: str = Query("pending", description="Tab lọc: pending hoặc reviewed"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestBatchSummary:
    """Lấy danh sách đơn xin nghỉ theo lớp học và tab trạng thái."""
    verify_class_access(class_id, current_user, db)

    # Đếm số lượng theo trạng thái
    pending_count = db.scalar(
        select(func.count(LeaveRequest.request_id)).where(
            LeaveRequest.class_id == class_id,
            LeaveRequest.status == LeaveRequestStatus.PENDING,
        )
    ) or 0

    reviewed_count = db.scalar(
        select(func.count(LeaveRequest.request_id)).where(
            LeaveRequest.class_id == class_id,
            LeaveRequest.status.in_([LeaveRequestStatus.APPROVED, LeaveRequestStatus.REJECTED]),
        )
    ) or 0

    # Lấy items theo tab
    query = select(LeaveRequest).where(LeaveRequest.class_id == class_id)
    if tab == "pending":
        query = query.where(LeaveRequest.status == LeaveRequestStatus.PENDING).order_by(LeaveRequest.created_at.desc())
    else:
        query = query.where(
            LeaveRequest.status.in_([LeaveRequestStatus.APPROVED, LeaveRequestStatus.REJECTED])
        ).order_by(LeaveRequest.reviewed_at.desc())

    requests = db.scalars(query).all()
    items = [_to_response_dto(r) for r in requests]

    return LeaveRequestBatchSummary(
        pending_count=pending_count,
        reviewed_count=reviewed_count,
        items=items,
    )


@router.get("/mine", response_model=LeaveRequestPage)
def get_my_leave_requests(
    child_id: uuid.UUID,
    status: LeaveRequestStatus | None = None,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestPage:
    require_parent(current_user)
    resolve_child_for_actor(db, child_id, current_user)
    filters = [LeaveRequest.child_id == child_id]
    if status is not None:
        filters.append(LeaveRequest.status == status)
    total = db.scalar(select(func.count(LeaveRequest.request_id)).where(*filters)) or 0
    requests = db.scalars(
        select(LeaveRequest).where(*filters)
        .order_by(LeaveRequest.created_at.desc(), LeaveRequest.request_id.desc())
        .offset(offset).limit(limit)
    ).all()
    return LeaveRequestPage(items=[_to_response_dto(req) for req in requests],
                            total=total, offset=offset, limit=limit)


@router.post("/attachments", response_model=LeaveRequestAttachmentResponse, status_code=201)
def upload_leave_attachment(
    child_id: uuid.UUID,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestAttachmentResponse:
    require_parent(current_user)
    resolve_child_for_actor(db, child_id, current_user)
    path = save_attachment(child_id, current_user.user_id,
                           file.file.read(MAX_IMAGE_BYTES + 1), file.content_type)
    return LeaveRequestAttachmentResponse(attachment_url=path)


@router.get("/attachments/{child_id}/{attachment_id}")
def get_leave_attachment(
    child_id: uuid.UUID,
    attachment_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    resolve_child_for_actor(db, child_id, current_user)
    data, content_type = read_attachment(child_id, attachment_id)
    return Response(content=data, media_type=content_type, headers={
        "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff",
    })


@router.get("/{request_id}", response_model=LeaveRequestResponse)
def get_leave_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestResponse:
    req = db.scalar(select(LeaveRequest).where(LeaveRequest.request_id == request_id))
    if req is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn xin nghỉ")
    if role_of(current_user) == "parent":
        resolve_child_for_actor(db, req.child_id, current_user)
    else:
        verify_class_access(req.class_id, current_user, db)
    return _to_response_dto(req)


@router.post("/{request_id}/approve", response_model=LeaveRequestResponse)
def approve_leave_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestResponse:
    """Duyệt đơn; chỉ đơn nghỉ mới bổ sung điểm danh vắng, không ghi đè đã đến."""
    req = review_request(db, request_id, current_user, LeaveRequestStatus.APPROVED,
                         datetime.now(timezone.utc))
    logger.info("Leave request approved: id=%s", req.request_id)
    return _to_response_dto(req)


@router.post("/{request_id}/reject", response_model=LeaveRequestResponse)
def reject_leave_request(
    request_id: uuid.UUID,
    payload: LeaveRequestReject,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestResponse:
    """Giáo viên từ chối đơn xin nghỉ kèm lý do bắt buộc."""
    req = review_request(db, request_id, current_user, LeaveRequestStatus.REJECTED,
                         datetime.now(timezone.utc), payload.reject_reason)
    logger.info("Leave request rejected: id=%s", req.request_id)
    return _to_response_dto(req)


@router.post("", response_model=LeaveRequestResponse, status_code=status.HTTP_201_CREATED)
@router.post("/parent", response_model=LeaveRequestResponse, status_code=status.HTTP_201_CREATED)
def create_leave_request(
    payload: LeaveRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestResponse:
    """Tạo đơn cho đúng bé được liên kết; lớp và người gửi lấy từ server."""
    req = create_request(db, payload, current_user)
    return _to_response_dto(req)
