"""API đơn thống nhất: batch, UI một bé, ảnh riêng tư, lịch sử và xử lý."""

import logging
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.access import resolve_child_for_actor, role_of
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.leave_request import LeaveRequest, LeaveRequestStatus, LeaveType
from app.models.user import User
from app.schemas.leave_request_schema import (
    LeaveBatchCreateResponse, LeaveRequestAttachmentResponse, LeaveRequestBatchSummary,
    LeaveRequestCancelResponse, LeaveRequestCreate, LeaveRequestPage, LeaveRequestReject,
    LeaveRequestResponse, LeaveRequestReviewResponse, ParentLeaveRequestCreate, StudentLeaveHistoryResponse,
)
from app.services.attendance_sync_service import cancel_leave_request as cancel_request
from app.services.attendance_sync_service import cancellation_metadata
from app.services.leave_request_attachments import MAX_IMAGE_BYTES, read_attachment, save_attachment
from app.services.leave_request_service import create_request, create_requests, require_parent, review_request, verify_class_access

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/leave-requests", tags=["leave-requests"])


def _to_response_dto(req: LeaveRequest, actor: User | None = None) -> LeaveRequestResponse:
    reviewer = req.reviewer
    reviewer_name = (reviewer.teacher.full_name if reviewer.teacher else reviewer.username) if reviewer else None
    kind = req.type or LeaveType.SINGLE_DAY
    return LeaveRequestResponse(
        request_id=req.leave_id, leave_id=req.leave_id, child_id=req.child_id,
        parent_id=req.parent_id, class_id=req.class_id, type=kind,
        request_type="late_arrival" if kind == LeaveType.LATE else "absence",
        from_date=req.from_date, to_date=req.to_date, reason=req.reason,
        expected_arrival_time=req.expected_arrival_time, attachment_url=req.attachment_url,
        meal_warning_acknowledged=req.meal_warning_acknowledged,
        submitted_after_cutoff=req.submitted_after_cutoff, contact_phone=req.contact_phone or "",
        status=req.status, reject_reason=req.reject_reason, reviewed_by=req.approved_by,
        reviewed_at=req.action_at, action_at=req.action_at, created_at=req.created_at, updated_at=req.updated_at,
        child_name=req.child.full_name if req.child else None,
        child_avatar_url=req.child.avatar_url if req.child else None,
        parent_name=req.parent.full_name if req.parent else None,
        reviewer_name=reviewer_name, approved_by_name=reviewer_name,
        **cancellation_metadata(req, actor.parent_id if actor is not None and role_of(actor) == "parent" else None),
    )


@router.post("", response_model=LeaveBatchCreateResponse | LeaveRequestResponse, status_code=201)
def create_leave_request(
    payload: LeaveRequestCreate | ParentLeaveRequestCreate,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    if isinstance(payload, ParentLeaveRequestCreate):
        return _to_response_dto(create_request(db, payload, current_user), current_user)
    requests = create_requests(db, payload, current_user)
    return LeaveBatchCreateResponse(total_created=len(requests), requests=[_to_response_dto(req, current_user) for req in requests])


@router.post("/parent", response_model=LeaveRequestResponse, status_code=201)
def create_parent_request(
    payload: ParentLeaveRequestCreate,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    return _to_response_dto(create_request(db, payload, current_user), current_user)


@router.get("/class/{class_id}", response_model=LeaveRequestBatchSummary)
def get_class_leave_requests(
    class_id: uuid.UUID, tab: str = "pending", offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    verify_class_access(class_id, current_user, db)
    reviewed = [LeaveRequestStatus.APPROVED, LeaveRequestStatus.REJECTED, LeaveRequestStatus.CANCELLED]
    counts = {state: db.scalar(select(func.count(LeaveRequest.leave_id)).where(
        LeaveRequest.class_id == class_id, LeaveRequest.status == state,
    )) or 0 for state in [LeaveRequestStatus.PENDING, *reviewed]}
    states = [LeaveRequestStatus.PENDING] if tab == "pending" else reviewed
    requests = db.scalars(select(LeaveRequest).where(LeaveRequest.class_id == class_id,
        LeaveRequest.status.in_(states)).order_by(LeaveRequest.created_at.desc(), LeaveRequest.leave_id.desc())
        .offset(offset).limit(limit)).all()
    return LeaveRequestBatchSummary(pending_count=counts[LeaveRequestStatus.PENDING],
        reviewed_count=sum(counts[state] for state in reviewed), items=[_to_response_dto(req, current_user) for req in requests])


@router.get("/mine", response_model=LeaveRequestPage)
def get_my_leave_requests(
    child_id: uuid.UUID, status: LeaveRequestStatus | None = None,
    offset: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    require_parent(current_user)
    resolve_child_for_actor(db, child_id, current_user)
    filters = [LeaveRequest.child_id == child_id]
    if status is not None:
        filters.append(LeaveRequest.status == status)
    total = db.scalar(select(func.count(LeaveRequest.leave_id)).where(*filters)) or 0
    requests = db.scalars(select(LeaveRequest).where(*filters)
        .order_by(LeaveRequest.created_at.desc(), LeaveRequest.leave_id.desc()).offset(offset).limit(limit)).all()
    return LeaveRequestPage(items=[_to_response_dto(req, current_user) for req in requests], total=total, offset=offset, limit=limit)


@router.get("/student/{child_id}", response_model=StudentLeaveHistoryResponse)
def get_student_leave_requests(
    child_id: uuid.UUID, status_filter: LeaveRequestStatus | None = None,
    offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    child = resolve_child_for_actor(db, child_id, current_user)
    filters = [LeaveRequest.child_id == child_id]
    if status_filter is not None:
        filters.append(LeaveRequest.status == status_filter)
    total = db.scalar(select(func.count(LeaveRequest.leave_id)).where(*filters)) or 0
    requests = db.scalars(select(LeaveRequest).where(*filters)
        .order_by(LeaveRequest.created_at.desc(), LeaveRequest.leave_id.desc()).offset(offset).limit(limit)).all()
    return StudentLeaveHistoryResponse(child_id=child_id, child_name=child.full_name, class_id=child.class_id,
        class_name=child.class_.name if child.class_ else None, total_requests=total,
        data=[_to_response_dto(req, current_user) for req in requests])


@router.post("/attachments", response_model=LeaveRequestAttachmentResponse, status_code=201)
def upload_leave_attachment(
    child_id: uuid.UUID, file: UploadFile = File(...),
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    require_parent(current_user)
    resolve_child_for_actor(db, child_id, current_user)
    path = save_attachment(child_id, current_user.user_id, file.file.read(MAX_IMAGE_BYTES + 1), file.content_type)
    return LeaveRequestAttachmentResponse(attachment_url=path)


@router.get("/attachments/{child_id}/{attachment_id}")
def get_leave_attachment(
    child_id: uuid.UUID, attachment_id: uuid.UUID,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    resolve_child_for_actor(db, child_id, current_user)
    data, content_type = read_attachment(child_id, attachment_id)
    return Response(content=data, media_type=content_type,
                    headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"})


@router.get("/{request_id}", response_model=LeaveRequestResponse)
def get_leave_request(
    request_id: uuid.UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    req = db.scalar(select(LeaveRequest).where(LeaveRequest.leave_id == request_id))
    if req is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn xin nghỉ")
    if role_of(current_user) == "parent":
        resolve_child_for_actor(db, req.child_id, current_user)
    else:
        verify_class_access(req.class_id, current_user, db)
    return _to_response_dto(req, current_user)


@router.post("/{request_id}/approve", response_model=LeaveRequestReviewResponse)
def approve_leave_request(
    request_id: uuid.UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    req, synced = review_request(db, request_id, current_user, LeaveRequestStatus.APPROVED)
    logger.info("Duyệt đơn: id=%s", req.leave_id)
    return LeaveRequestReviewResponse(**_to_response_dto(req, current_user).model_dump(), success=True,
        message="Đã duyệt đơn xin phép", synced_attendance_count=synced)


@router.post("/{request_id}/reject", response_model=LeaveRequestReviewResponse)
def reject_leave_request(
    request_id: uuid.UUID, payload: LeaveRequestReject,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    req, _ = review_request(db, request_id, current_user, LeaveRequestStatus.REJECTED, reject_reason=payload.reason)
    logger.info("Từ chối đơn: id=%s", req.leave_id)
    return LeaveRequestReviewResponse(**_to_response_dto(req, current_user).model_dump(), success=True,
        message="Đã từ chối đơn", synced_attendance_count=0)


@router.post("/{request_id}/cancel", response_model=LeaveRequestCancelResponse)
def cancel_leave_request_endpoint(
    request_id: uuid.UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user),
):
    require_parent(current_user)
    child_id = db.scalar(select(LeaveRequest.child_id).where(LeaveRequest.leave_id == request_id))
    if child_id is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn xin nghỉ")
    resolve_child_for_actor(db, child_id, current_user)
    req, rollbacked = cancel_request(db, request_id, current_user.parent_id)
    return LeaveRequestCancelResponse(success=True, message="Đã hủy đơn", leave_id=req.leave_id,
        status=req.status, rollbacked_attendance=rollbacked)
