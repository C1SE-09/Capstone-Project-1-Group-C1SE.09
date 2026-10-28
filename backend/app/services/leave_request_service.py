"""Nghiệp vụ đơn nghỉ/báo trễ; khóa DB thay vì khóa trong một process."""

import uuid
from datetime import datetime, time, timedelta

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session, lazyload

from app.config import vn_tz
from app.core.access import resolve_child_for_actor, role_of
from app.models.attendance import AttendanceRecord, AttendanceStatus
from app.models.child import Child
from app.models.leave_request import LeaveRequest, LeaveRequestStatus
from app.models.user import Teacher, User
from app.schemas.leave_request_schema import LeaveRequestCreate
from app.services.leave_request_attachments import validate_attachment_reference

MEAL_WARNING = "Đơn gửi sau 7:30 vẫn có thể tính tiền ăn bán trú hôm nay. Bạn có đồng ý không"


def require_parent(user: User) -> None:
    if role_of(user) != "parent" or not user.parent_id:
        raise HTTPException(status_code=403, detail="Chỉ phụ huynh được gửi/xem lịch sử đơn của bé")


def verify_class_access(class_id: uuid.UUID, user: User, db: Session) -> None:
    """Giáo viên chỉ xử lý lớp được phân công; admin được đọc/xử lý."""
    if role_of(user) == "admin":
        return
    if role_of(user) == "teacher" and user.teacher_id:
        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == user.teacher_id))
        if teacher and teacher.class_id == class_id:
            return
    raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập dữ liệu của lớp học này")


def create_request(db: Session, payload: LeaveRequestCreate, user: User) -> LeaveRequest:
    require_parent(user)
    # OF child tránh khóa các bảng nullable được ORM joined-load cùng hồ sơ bé.
    child = db.scalar(
        select(Child).options(lazyload("*")).where(Child.child_id == payload.child_id)
        .with_for_update(of=Child).execution_options(populate_existing=True)
    )
    if child is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy hồ sơ bé")
    resolve_child_for_actor(db, child.child_id, user)
    if child.class_id is None or (payload.class_id is not None and payload.class_id != child.class_id):
        raise HTTPException(status_code=422, detail="Lớp học không khớp hồ sơ bé")

    local_now = datetime.now(vn_tz)
    if payload.from_date < local_now.date():
        raise HTTPException(status_code=422, detail="Không thể gửi đơn cho ngày đã qua")
    if (payload.request_type == "late_arrival" and payload.from_date == local_now.date()
            and payload.expected_arrival_time <= local_now.time()):
        raise HTTPException(status_code=422, detail="Giờ đến dự kiến phải sau thời điểm hiện tại")
    if (payload.from_date <= local_now.date() <= payload.to_date
            and local_now.time() > time(7, 30) and not payload.meal_warning_acknowledged):
        raise HTTPException(status_code=409, detail={"code": "meal_warning_required", "message": MEAL_WARNING})

    overlap = db.scalar(select(LeaveRequest.request_id).where(
        LeaveRequest.child_id == child.child_id,
        LeaveRequest.status.in_([LeaveRequestStatus.PENDING, LeaveRequestStatus.APPROVED]),
        LeaveRequest.from_date <= payload.to_date,
        LeaveRequest.to_date >= payload.from_date,
    ).limit(1))
    if overlap:
        raise HTTPException(status_code=409, detail={
            "code": "overlapping_request", "message": "Bé đã có đơn chờ duyệt hoặc đã duyệt trong khoảng ngày này",
        })

    if payload.attachment_url is not None:
        validate_attachment_reference(payload.attachment_url, child.child_id, user.user_id)

    req = LeaveRequest(
        **payload.model_dump(exclude={"class_id"}),
        parent_id=user.parent_id, class_id=child.class_id, status=LeaveRequestStatus.PENDING,
    )
    db.add(req)
    db.commit()
    db.refresh(req)
    return req


def review_request(
    db: Session, request_id: uuid.UUID, user: User, decision: LeaveRequestStatus,
    now: datetime, reject_reason: str | None = None,
) -> LeaveRequest:
    req = db.scalar(
        select(LeaveRequest).where(LeaveRequest.request_id == request_id)
        .with_for_update(of=LeaveRequest).execution_options(populate_existing=True)
    )
    if req is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn xin nghỉ")
    verify_class_access(req.class_id, user, db)
    if req.status != LeaveRequestStatus.PENDING:
        raise HTTPException(status_code=400, detail="Đơn đã được xử lý trước đó")

    if decision == LeaveRequestStatus.APPROVED and req.request_type == "absence":
        # Chặn cả dữ liệu cũ bất thường trước vòng lặp đồng bộ điểm danh.
        if not 0 <= (req.to_date - req.from_date).days < 366:
            raise HTTPException(status_code=422, detail="Khoảng ngày không hợp lệ hoặc vượt quá 366 ngày")
        for day in range((req.to_date - req.from_date).days + 1):
            stmt = insert(AttendanceRecord).values(
                record_id=uuid.uuid4(), child_id=req.child_id, class_id=req.class_id,
                date=req.from_date + timedelta(days=day), status=AttendanceStatus.ABSENT,
                note="Nghỉ có phép", teacher_id=user.teacher_id,
            )
            db.execute(stmt.on_conflict_do_update(
                index_elements=["child_id", "date"],
                set_={"note": "Nghỉ có phép", "teacher_id": user.teacher_id, "updated_at": func.now()},
                where=(AttendanceRecord.status == AttendanceStatus.ABSENT)
                & AttendanceRecord.check_in_time.is_(None),
            ))

    req.status = decision
    req.reviewed_by = user.teacher_id
    req.reviewed_at = now
    req.reject_reason = reject_reason if decision == LeaveRequestStatus.REJECTED else None
    db.commit()
    db.refresh(req)
    return req
