"""Một luồng nghiệp vụ dùng chung cho API batch, UI phụ huynh và xét duyệt."""

import uuid
import re
from datetime import datetime, time

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, lazyload

from app.config import vn_tz
from app.core.access import resolve_child_for_actor, role_of
from app.models.child import Child, ChildStatus, Parent
from app.models.leave_request import LeaveRequest, LeaveRequestStatus, LeaveType
from app.models.user import Teacher, User
from app.schemas.leave_request_schema import ChildScheduleInput, LeaveRequestCreate, ParentLeaveRequestCreate
from app.services.leave_request_attachments import ATTACHMENT_PREFIX, copy_attachment_for_child, validate_attachment_reference

MEAL_WARNING = "Đơn gửi sau 7:30 vẫn có thể tính tiền ăn bán trú hôm nay. Bạn có đồng ý không"


def require_parent(user: User) -> None:
    if role_of(user) != "parent" or not user.parent_id:
        raise HTTPException(status_code=403, detail="Chỉ phụ huynh được gửi/xem lịch sử đơn của bé")


def verify_class_access(class_id: uuid.UUID, user: User, db: Session) -> None:
    if role_of(user) == "admin":
        return
    if role_of(user) == "teacher" and user.teacher_id:
        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == user.teacher_id))
        if teacher and teacher.class_id == class_id:
            return
    raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập dữ liệu của lớp học này")


def create_requests(
    db: Session, payload: LeaveRequestCreate, user: User, *, expected_class_id: uuid.UUID | None = None,
) -> list[LeaveRequest]:
    require_parent(user)
    # Khóa theo thứ tự UUID cố định, tránh deadlock khi hai phụ huynh chọn nhiều bé.
    children = {}
    for child_id in sorted(item.child_id for item in payload.children):
        child = db.scalar(select(Child).options(lazyload("*")).where(Child.child_id == child_id)
                          .with_for_update(of=Child).execution_options(populate_existing=True))
        if child is None or child.status != ChildStatus.ENROLLED:
            raise HTTPException(status_code=404, detail="Không tìm thấy hồ sơ bé")
        resolve_child_for_actor(db, child_id, user)
        if child.class_id is None or (expected_class_id is not None and child.class_id != expected_class_id):
            raise HTTPException(status_code=422, detail="Lớp học không khớp hồ sơ bé")
        children[child_id] = child

    now = datetime.now(vn_tz)
    needs_warning = any(item.from_date <= now.date() <= item.to_date for item in payload.children)
    if needs_warning and now.time() > time(7, 30) and not payload.meal_warning_acknowledged:
        raise HTTPException(status_code=409, detail={"code": "meal_warning_required", "message": MEAL_WARNING})

    for item in payload.children:
        if item.from_date < now.date():
            raise HTTPException(status_code=422, detail="Không thể gửi đơn cho ngày đã qua")
        if (item.type == LeaveType.LATE and item.from_date == now.date()
                and item.expected_arrival_time <= now.time()):
            raise HTTPException(status_code=422, detail="Giờ đến dự kiến phải sau thời điểm hiện tại")
        overlap = db.scalar(select(LeaveRequest.leave_id).where(
            LeaveRequest.child_id == item.child_id,
            LeaveRequest.status.in_([LeaveRequestStatus.PENDING, LeaveRequestStatus.APPROVED]),
            LeaveRequest.from_date <= item.to_date, LeaveRequest.to_date >= item.from_date,
        ).limit(1))
        if overlap:
            raise HTTPException(status_code=409, detail={
                "code": "overlapping_request", "message": "Bé đã có đơn chờ duyệt hoặc đã duyệt trong khoảng ngày này",
            })

    attachments = {}
    if payload.attachment_url is not None:
        source_child = next((child_id for child_id in children
                             if payload.attachment_url.startswith(f"{ATTACHMENT_PREFIX}{child_id}/")), None)
        if source_child is None:
            raise HTTPException(status_code=422, detail="Ảnh đính kèm phải thuộc một bé trong đơn")
        validate_attachment_reference(payload.attachment_url, source_child, user.user_id)
        attachments = {child_id: payload.attachment_url if child_id == source_child else
                       copy_attachment_for_child(payload.attachment_url, source_child, child_id, user.user_id)
                       for child_id in children}

    parent = db.get(Parent, user.parent_id)
    phone = payload.contact_phone or (parent.phone if parent else "")
    if not phone or not re.fullmatch(r"0\d{9}", phone):
        raise HTTPException(status_code=400, detail="Vui lòng cập nhật số điện thoại liên hệ 10 chữ số trong tài khoản")
    requests = [LeaveRequest(
        **item.model_dump(), class_id=children[item.child_id].class_id, parent_id=user.parent_id,
        reason=payload.reason, attachment_url=attachments.get(item.child_id), contact_phone=phone,
        status=LeaveRequestStatus.PENDING, meal_warning_acknowledged=payload.meal_warning_acknowledged,
        submitted_after_cutoff=item.from_date <= now.date() <= item.to_date and now.time() > time(7, 30),
    ) for item in payload.children]
    db.add_all(requests)
    db.commit()
    for request in requests:
        db.refresh(request)
    return requests


def create_request(db: Session, payload: ParentLeaveRequestCreate, user: User) -> LeaveRequest:
    """Adapter chỉ đổi shape; mọi kiểm tra và ghi DB nằm trong create_requests."""
    kind = LeaveType.LATE if payload.request_type == "late_arrival" else (
        LeaveType.SINGLE_DAY if payload.from_date == payload.to_date else LeaveType.MULTI_DAY)
    schedule = ChildScheduleInput(child_id=payload.child_id, type=kind,
        from_date=payload.from_date, to_date=payload.to_date, expected_arrival_time=payload.expected_arrival_time)
    batch = LeaveRequestCreate(children=[schedule], reason=payload.reason,
        attachment_url=payload.attachment_url, meal_warning_acknowledged=payload.meal_warning_acknowledged)
    return create_requests(db, batch, user, expected_class_id=payload.class_id)[0]


def review_request(
    db: Session, request_id: uuid.UUID, user: User, decision: LeaveRequestStatus,
    now: datetime | None = None, reject_reason: str | None = None,
) -> tuple[LeaveRequest, int]:
    from app.services.attendance_sync_service import sync_leave_request_to_attendance

    req = db.scalar(select(LeaveRequest).where(LeaveRequest.leave_id == request_id)
                    .with_for_update(of=LeaveRequest).execution_options(populate_existing=True))
    if req is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn xin nghỉ")
    verify_class_access(req.class_id, user, db)
    if req.status != LeaveRequestStatus.PENDING:
        raise HTTPException(status_code=400, detail="Đơn đã được xử lý trước đó")
    if decision == LeaveRequestStatus.APPROVED and (
        req.child is None or req.child.status != ChildStatus.ENROLLED or req.child.class_id != req.class_id
    ):
        raise HTTPException(status_code=409, detail="Hồ sơ bé đã thay đổi. Vui lòng tạo lại đơn theo lớp hiện tại")
    req.status = decision
    req.approved_by = user.user_id
    req.action_at = now or datetime.now(vn_tz)
    req.reject_reason = reject_reason if decision == LeaveRequestStatus.REJECTED else None
    synced = sync_leave_request_to_attendance(db, req, user.teacher_id) if decision == LeaveRequestStatus.APPROVED else []
    db.commit()
    db.refresh(req)
    return req, len(synced)
