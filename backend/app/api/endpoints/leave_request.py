"""
backend/app/api/endpoints/leave_requests.py
===========================================
API tạo đơn xin nghỉ / đi trễ & xem lịch sử đơn của học sinh.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.child import Child, ChildStatus, Parent, ParentChild
from app.models.leave_request import LeaveRequest, LeaveStatus, LeaveType
from app.models.user import Teacher, User, UserRole
from app.schemas.leave_request_schema import (
    ChildScheduleInput,
    LeaveBatchCreateResponse,
    LeaveRequestCreate,
    LeaveRequestResponse,
    StudentLeaveHistoryItem,
    StudentLeaveHistoryResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/leave-requests", tags=["leave-requests"])

VN_TZ = ZoneInfo("Asia/Ho_Chi_Minh")
CUTOFF_TIME = time(7, 30)


def _resolve_contact_phone(db: Session, parent_id: uuid.UUID, phone_input: str | None) -> str:
    """Tự động điền SĐT từ tài khoản phụ huynh nếu để trống."""
    if phone_input and phone_input.strip():
        return phone_input.strip()

    parent = db.scalar(select(Parent).where(Parent.parent_id == parent_id))
    if parent and parent.phone and parent.phone.strip():
        phone = parent.phone.strip()
        if len(phone) == 10 and phone.startswith("0"):
            return phone

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Tài khoản chưa có số điện thoại liên hệ. Vui lòng nhập số điện thoại trên đơn.",
    )


def _verify_child_belongs_to_parent(db: Session, parent_id: uuid.UUID, child_id: uuid.UUID) -> Child:
    """Bảo mật IDOR: Kiểm tra quyền phụ huynh đối với từng bé."""
    child = db.scalar(
        select(Child).where(Child.child_id == child_id, Child.status == ChildStatus.ENROLLED)
    )
    if not child:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy học sinh hoặc bé đã thôi học.")

    is_owner = (child.parent_id == parent_id) or bool(
        db.scalar(select(ParentChild).where(ParentChild.child_id == child_id, ParentChild.parent_id == parent_id))
    )
    if not is_owner:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Bảo mật: Bạn không có quyền gửi đơn cho học sinh {child.full_name}!",
        )

    if not child.class_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Bé {child.full_name} chưa được xếp lớp. Vui lòng liên hệ nhà trường.",
        )

    return child


def _validate_leave_conflict(
    db: Session,
    child: Child,
    schedule: ChildScheduleInput,
    now_vn: datetime,
) -> None:
    """Kiểm tra trùng đơn thông minh cho từng bé."""
    active_requests = db.scalars(
        select(LeaveRequest)
        .where(
            LeaveRequest.child_id == child.child_id,
            LeaveRequest.status.in_([LeaveStatus.PENDING, LeaveStatus.APPROVED]),
            LeaveRequest.from_date <= schedule.to_date,
            LeaveRequest.to_date >= schedule.from_date,
        )
        .order_by(desc(LeaveRequest.created_at))
    ).all()

    if not active_requests:
        return

    # 1. Đơn nghỉ 1 ngày
    if schedule.type == LeaveType.SINGLE_DAY:
        for req in active_requests:
            if req.type in (LeaveType.SINGLE_DAY, LeaveType.MULTI_DAY):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Bé {child.full_name} đã có đơn xin nghỉ vào ngày {schedule.from_date.strftime('%d/%m/%Y')}. Không thể gửi trùng đơn.",
                )

    # 2. Đơn đi trễ
    elif schedule.type == LeaveType.LATE:
        late_requests = [r for r in active_requests if r.type == LeaveType.LATE and r.from_date == schedule.from_date]
        if late_requests:
            if len(late_requests) >= 2:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Bé {child.full_name} đã gửi đơn đi trễ 2 lần hôm nay. Vui lòng gọi trực tiếp cho cô giáo.",
                )
            last_late = late_requests[0]
            if last_late.expected_arrival_time:
                old_time = last_late.expected_arrival_time
                old_dt = datetime.combine(schedule.from_date, old_time, tzinfo=VN_TZ)
                allowed_resend_dt = old_dt + timedelta(minutes=5)
                if now_vn < allowed_resend_dt:
                    diff_minutes = max(1, int((allowed_resend_dt - now_vn).total_seconds() + 59) // 60)
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Bé {child.full_name} đã báo đến lúc {old_time.strftime('%H:%M')}. Vui lòng chờ {diff_minutes} phút nữa để gửi mốc giờ mới.",
                    )
                if schedule.expected_arrival_time and schedule.expected_arrival_time <= old_time:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Giờ đến mới của bé {child.full_name} phải sau giờ hẹn cũ ({old_time.strftime('%H:%M')}).",
                    )

    # 3. Đơn nghỉ nhiều ngày
    elif schedule.type == LeaveType.MULTI_DAY:
        for req in active_requests:
            if req.type == LeaveType.MULTI_DAY:
                if now_vn.date() <= req.from_date:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Bé {child.full_name} đã có đơn nghỉ từ {req.from_date.strftime('%d/%m/%Y')} đến {req.to_date.strftime('%d/%m/%Y')}.",
                    )
                elif schedule.to_date <= req.to_date:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Đơn gia hạn của bé {child.full_name} phải có ngày kết thúc sau ngày {req.to_date.strftime('%d/%m/%Y')}.",
                    )


@router.post("", response_model=LeaveBatchCreateResponse, status_code=status.HTTP_201_CREATED)
def create_leave_request(
    payload: LeaveRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("parent")),
):
    """
    Tạo đơn xin nghỉ học / báo đi trễ:
    Hỗ trợ gửi cho 1 bé, hoặc cả 2 bé (dù chung ngày hay khác ngày).
    """
    if not current_user.parent_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Tài khoản chưa được liên kết với hồ sơ phụ huynh.")

    # 1. Tự động lấy số điện thoại liên hệ từ tài khoản nếu để trống
    contact_phone = _resolve_contact_phone(
        db=db,
        parent_id=current_user.parent_id,
        phone_input=payload.contact_phone,
    )

    now_vn = datetime.now(VN_TZ)

    # 2. Xác thực và validate toàn bộ các bé trước khi lưu
    validated_items: list[tuple[Child, ChildScheduleInput]] = []
    for item in payload.children:
        child = _verify_child_belongs_to_parent(db=db, parent_id=current_user.parent_id, child_id=item.child_id)
        _validate_leave_conflict(db=db, child=child, schedule=item, now_vn=now_vn)
        validated_items.append((child, item))

    # 3. Tạo các bản ghi LeaveRequest (Trong 1 Transaction an toàn)
    created_entities: list[tuple[LeaveRequest, Child, str | None]] = []
    for child, schedule in validated_items:
        submitted_after_cutoff = False
        warning_message = None
        if schedule.from_date == now_vn.date() and now_vn.time() > CUTOFF_TIME:
            submitted_after_cutoff = True
            warning_message = "Đơn gửi sau 7:30 vẫn có thể tính tiền ăn bán trú hôm nay. Bạn có đồng ý không"

        new_req = LeaveRequest(
            child_id=child.child_id,
            parent_id=current_user.parent_id,
            class_id=child.class_id,
            type=schedule.type,
            from_date=schedule.from_date,
            to_date=schedule.to_date,
            expected_arrival_time=schedule.expected_arrival_time,
            reason=payload.reason,
            attachment_url=payload.attachment_url,
            contact_phone=contact_phone,
            submitted_after_cutoff=submitted_after_cutoff,
            status=LeaveStatus.PENDING,
        )
        db.add(new_req)
        created_entities.append((new_req, child, warning_message))

    # Commit toàn bộ
    db.commit()

    # 4. Trả về kết quả
    response_items: list[LeaveRequestResponse] = []
    for new_req, child, warning_msg in created_entities:
        db.refresh(new_req)
        response_items.append(
            LeaveRequestResponse(
                leave_id=new_req.leave_id,
                child_id=new_req.child_id,
                child_name=child.full_name,
                class_id=new_req.class_id,
                type=new_req.type,
                from_date=new_req.from_date,
                to_date=new_req.to_date,
                expected_arrival_time=new_req.expected_arrival_time,
                reason=new_req.reason,
                attachment_url=new_req.attachment_url,
                contact_phone=new_req.contact_phone,
                status=new_req.status,
                submitted_after_cutoff=new_req.submitted_after_cutoff,
                warning_message=warning_msg,
                created_at=new_req.created_at,
            )
        )

    return LeaveBatchCreateResponse(
        total_created=len(response_items),
        requests=response_items,
    )


def _verify_child_read_access(db: Session, current_user: User, child_id: uuid.UUID) -> Child:
    """
    BẢO MẬT ĐA TẦNG:
    - Admin: Toàn quyền truy cập.
    - Phụ huynh: Chỉ xem được con ruột của mình (Chặn 403 IDOR).
    - Giáo viên: Chỉ xem được học sinh thuộc lớp mình phụ trách (Chặn 403 xem chéo lớp).
    """
    child = db.scalar(
        select(Child).where(Child.child_id == child_id)
    )
    if not child:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy thông tin học sinh trong hệ thống.",
        )

    role_val = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)

    # 1. Admin
    if role_val == UserRole.ADMIN.value:
        return child

    # 2. Phụ huynh
    if role_val == UserRole.PARENT.value:
        if not current_user.parent_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Tài khoản chưa được liên kết phụ huynh.")
        
        is_owner = (child.parent_id == current_user.parent_id) or bool(
            db.scalar(select(ParentChild).where(ParentChild.child_id == child_id, ParentChild.parent_id == current_user.parent_id))
        )
        if not is_owner:
            logger.warning("BẢO MẬT: Phụ huynh %s cố tình xem đơn của bé %s", current_user.parent_id, child_id)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bảo mật: Bạn không có quyền xem đơn của học sinh này!",
            )
        return child

    # 3. Giáo viên
    if role_val == UserRole.TEACHER.value:
        if not current_user.teacher_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Tài khoản giáo viên chưa liên kết nhân sự.")
        
        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
        if not teacher or teacher.class_id != child.class_id:
            logger.warning("BẢO MẬT: Giáo viên %s cố tình xem đơn học sinh lớp khác %s", current_user.teacher_id, child.class_id)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bảo mật: Bạn chỉ có quyền xem đơn của học sinh thuộc lớp mình phụ trách!",
            )
        return child

    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Không có quyền truy cập.")


@router.get(
    "/student/{child_id}",
    response_model=StudentLeaveHistoryResponse,
    summary="Xem lịch sử và trạng thái đơn xin nghỉ của một học sinh (AC4)",
)
def get_student_leave_requests(
    child_id: uuid.UUID,
    status_filter: LeaveStatus | None = None,
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Phụ huynh / Giáo viên xem danh sách các đơn đã gửi của bé:
    - Hiển thị rõ trạng thái: Chờ duyệt (pending), Đã duyệt (approved), Bị từ chối (rejected).
    - Có lý do từ chối nếu bị cô từ chối.
    """
    # 1. Kiểm tra phân quyền truy cập nghiêm ngặt
    child = _verify_child_read_access(db=db, current_user=current_user, child_id=child_id)

    # 2. Xây dựng câu truy vấn
    query = select(LeaveRequest).where(LeaveRequest.child_id == child_id)

    if status_filter is not None:
        query = query.where(LeaveRequest.status == status_filter)

    query = query.order_by(desc(LeaveRequest.created_at)).offset(offset).limit(limit)
    leave_records = db.scalars(query).all()

    # 3. Format dữ liệu trả về kèm tên người duyệt (nếu có)
    items: list[StudentLeaveHistoryItem] = []
    for req in leave_records:
        approver_name = None
        if req.approved_by:
            approver = db.scalar(select(User).where(User.user_id == req.approved_by))
            approver_name = approver.full_name if approver else None

        items.append(
            StudentLeaveHistoryItem(
                leave_id=req.leave_id,
                type=req.type,
                from_date=req.from_date,
                to_date=req.to_date,
                expected_arrival_time=req.expected_arrival_time,
                reason=req.reason,
                attachment_url=req.attachment_url,
                contact_phone=req.contact_phone,
                status=req.status,
                submitted_after_cutoff=req.submitted_after_cutoff,
                approved_by_name=approver_name,
                reject_reason=req.reject_reason,
                action_at=req.action_at,
                created_at=req.created_at,
            )
        )

    # Lấy tên lớp
    class_name = child.class_.name if child.class_ else None

    return StudentLeaveHistoryResponse(
        child_id=child.child_id,
        child_name=child.full_name,
        class_id=child.class_id,
        class_name=class_name,
        total_requests=len(items),
        data=items,
    )