"""
backend/app/api/endpoints/leave_requests.py
===========================================
API Quản lý Đơn xin nghỉ học (Leave Requests):
- GET  /api/leave-requests/class/{class_id}: Danh sách đơn của lớp (lọc theo tab: pending / reviewed)
- POST /api/leave-requests/{request_id}/approve: Duyệt đơn 1-tap & tự động đồng bộ sang bảng attendance_record
- POST /api/leave-requests/{request_id}/reject: Từ chối đơn kèm lý do bắt buộc
- POST /api/leave-requests: Tạo đơn xin nghỉ học mới
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.attendance import AttendanceRecord, AttendanceStatus
from app.models.child import Child
from app.models.leave_request import LeaveRequest, LeaveRequestStatus
from app.models.user import Teacher, User, UserRole
from app.schemas.leave_request_schema import (
    LeaveRequestBatchSummary,
    LeaveRequestCreate,
    LeaveRequestReject,
    LeaveRequestResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/leave-requests", tags=["leave-requests"])


def verify_class_access(class_id: uuid.UUID, current_user: User, db: Session) -> None:
    """Kiểm tra quyền truy cập lớp học của người dùng."""
    role_val = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    if role_val == UserRole.ADMIN.value:
        return

    if role_val == UserRole.TEACHER.value:
        if not current_user.teacher_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tài khoản giáo viên chưa được liên kết với hồ sơ nhân sự",
            )
        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
        if not teacher or teacher.class_id != class_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền truy cập dữ liệu của lớp học này",
            )
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Quyền hạn không hợp lệ",
    )


def _to_response_dto(req: LeaveRequest) -> LeaveRequestResponse:
    """Map SQLAlchemy LeaveRequest sang LeaveRequestResponse DTO."""
    child_name = req.child.full_name if req.child else None
    child_avatar_url = req.child.avatar_url if req.child else None
    parent_name = req.parent.user.full_name if req.parent and req.parent.user else None
    reviewer_name = req.reviewer.user.full_name if req.reviewer and req.reviewer.user else None

    return LeaveRequestResponse(
        request_id=req.request_id,
        child_id=req.child_id,
        parent_id=req.parent_id,
        class_id=req.class_id,
        from_date=req.from_date,
        to_date=req.to_date,
        reason=req.reason,
        attachment_url=req.attachment_url,
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


@router.post("/{request_id}/approve", response_model=LeaveRequestResponse)
def approve_leave_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestResponse:
    """
    Giáo viên duyệt đơn xin nghỉ (1-tap Approve):
    - Đổi status sang APPROVED
    - Tự động Upsert điểm danh: ABSENT (note='Nghỉ có phép') cho các ngày từ from_date đến to_date
    """
    req = db.scalar(select(LeaveRequest).where(LeaveRequest.request_id == request_id))
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy đơn xin nghỉ")

    verify_class_access(req.class_id, current_user, db)

    if req.status != LeaveRequestStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Đơn đã được xử lý trước đó với trạng thái: {req.status.value}",
        )

    teacher_id = current_user.teacher_id if hasattr(current_user, "teacher_id") else None

    # 1. Cập nhật trạng thái đơn
    req.status = LeaveRequestStatus.APPROVED
    req.reviewed_by = teacher_id
    req.reviewed_at = datetime.now(timezone.utc)
    req.reject_reason = None

    # 2. Tự động đồng bộ sang bảng attendance_record
    # Duyệt từ from_date đến to_date (bỏ qua Chủ nhật nếu không học)
    curr = req.from_date
    while curr <= req.to_date:
        # Nếu là thứ 7 hoặc Chủ nhật có thể tùy trường mầm non, ở đây điểm danh tất cả các ngày trong đơn
        insert_stmt = insert(AttendanceRecord).values(
            record_id=uuid.uuid4(),
            child_id=req.child_id,
            class_id=req.class_id,
            date=curr,
            status=AttendanceStatus.ABSENT,
            note=f"Nghỉ có phép: {req.reason[:100]}",
            teacher_id=teacher_id,
        )
        upsert_stmt = insert_stmt.on_conflict_do_update(
            constraint="uq_attendance_child_date",
            set_={
                "status": AttendanceStatus.ABSENT,
                "note": f"Nghỉ có phép: {req.reason[:100]}",
                "teacher_id": teacher_id,
                "updated_at": func.now(),
            },
        )
        db.execute(upsert_stmt)
        curr += timedelta(days=1)

    db.commit()
    db.refresh(req)
    logger.info(
        "Leave request approved: id=%s child=%s from=%s to=%s",
        req.request_id,
        req.child_id,
        req.from_date,
        req.to_date,
    )
    return _to_response_dto(req)


@router.post("/{request_id}/reject", response_model=LeaveRequestResponse)
def reject_leave_request(
    request_id: uuid.UUID,
    payload: LeaveRequestReject,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestResponse:
    """Giáo viên từ chối đơn xin nghỉ kèm lý do bắt buộc."""
    reason = payload.reject_reason.strip()
    if not reason:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Lý do từ chối không được để trống",
        )

    req = db.scalar(select(LeaveRequest).where(LeaveRequest.request_id == request_id))
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy đơn xin nghỉ")

    verify_class_access(req.class_id, current_user, db)

    if req.status != LeaveRequestStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Đơn đã được xử lý trước đó với trạng thái: {req.status.value}",
        )

    teacher_id = current_user.teacher_id if hasattr(current_user, "teacher_id") else None

    req.status = LeaveRequestStatus.REJECTED
    req.reject_reason = reason
    req.reviewed_by = teacher_id
    req.reviewed_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(req)
    logger.info("Leave request rejected: id=%s reason=%s", req.request_id, reason)
    return _to_response_dto(req)


@router.post("", response_model=LeaveRequestResponse, status_code=status.HTTP_201_CREATED)
def create_leave_request(
    payload: LeaveRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LeaveRequestResponse:
    """Tạo đơn xin nghỉ học mới."""
    if payload.to_date < payload.from_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ngày kết thúc nghỉ không thể trước ngày bắt đầu",
        )

    # Xác định parent_id từ current_user nếu là Phụ huynh, hoặc gán từ liên kết
    parent_id = None
    if hasattr(current_user, "parent_id") and current_user.parent_id:
        parent_id = current_user.parent_id
    else:
        # Nếu là admin/teacher tạo hộ hoặc test, tìm parent đầu tiên của trẻ
        child = db.scalar(select(Child).where(Child.child_id == payload.child_id))
        if not child:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy học sinh")
        if child.parents:
            parent_id = child.parents[0].parent_id
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Học sinh chưa có thông tin phụ huynh liên kết",
            )

    new_req = LeaveRequest(
        request_id=uuid.uuid4(),
        child_id=payload.child_id,
        parent_id=parent_id,
        class_id=payload.class_id,
        from_date=payload.from_date,
        to_date=payload.to_date,
        reason=payload.reason.strip(),
        attachment_url=payload.attachment_url,
        status=LeaveRequestStatus.PENDING,
    )
    db.add(new_req)
    db.commit()
    db.refresh(new_req)
    return _to_response_dto(new_req)
