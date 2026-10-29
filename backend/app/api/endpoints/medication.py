"""
app/api/endpoints/medication.py
===============================
API Dặn thuốc & Theo dõi cữ uống thuốc của học sinh.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ChildStatus, Parent, ParentChild
from app.models.medication import MedicationRequest, MedicationStatus
from app.models.user import Class_, Teacher, User, UserRole
from app.schemas.medication_schema import (
    MedicationBatchCreateResponse,
    MedicationConfirmRequest,
    MedicationRequestCreate,
    MedicationRequestResponse,
)
from app.services.notification_service import (
    child_parents_device_tokens,
    send_push_notification,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/medication-requests", tags=["medication-requests"])

VN_TZ = ZoneInfo("Asia/Ho_Chi_Minh")


def _resolve_child(db: Session, child_id: uuid.UUID) -> Child:
    child = db.scalar(
        select(Child).where(Child.child_id == child_id, Child.status == ChildStatus.ENROLLED)
    )
    if not child:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy học sinh hoặc bé đã thôi học.",
        )
    return child


def _verify_child_access(db: Session, current_user: User, child_id: uuid.UUID) -> Child:
    child = _resolve_child(db, child_id)
    if current_user.role == UserRole.PARENT:
        parent_id = current_user.parent_id
        if not parent_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tài khoản chưa được liên kết với hồ sơ phụ huynh.",
            )
        is_owner = (child.parent_id == parent_id) or bool(
            db.scalar(
                select(ParentChild).where(
                    ParentChild.child_id == child_id,
                    ParentChild.parent_id == parent_id,
                )
            )
        )
        if not is_owner:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền quản lý đơn thuốc cho học sinh này.",
            )
    return child


def _to_response(req: MedicationRequest, db: Session) -> MedicationRequestResponse:
    # Resolve child name & class name
    child = req.child or db.scalar(select(Child).where(Child.child_id == req.child_id))
    child_name = child.full_name if child else "Học sinh"

    class_name = None
    if req.class_id:
        class_ = req.class_ or db.scalar(select(Class_).where(Class_.class_id == req.class_id))
        class_name = class_.name if class_ else None

    # Resolve parent name
    parent = req.parent or db.scalar(select(Parent).where(Parent.parent_id == req.parent_id))
    parent_name = parent.full_name if parent else None

    # Resolve creator name
    creator_name = "Người dùng"
    if req.created_by_role == "parent":
        creator_name = parent_name or "Phụ huynh"
    elif req.created_by_role == "teacher":
        creator_user = req.created_by_user or db.scalar(
            select(User).where(User.user_id == req.created_by_user_id)
        )
        if creator_user and creator_user.teacher_id:
            t = db.scalar(select(Teacher).where(Teacher.teacher_id == creator_user.teacher_id))
            creator_name = t.full_name if t else creator_user.username
        else:
            creator_name = creator_user.username if creator_user else "Giáo viên"

    # Resolve given by name
    given_by_name = None
    if req.given_by_id:
        t = req.teacher or db.scalar(select(Teacher).where(Teacher.teacher_id == req.given_by_id))
        given_by_name = t.full_name if t else None

    now_vn = datetime.now(VN_TZ)
    return MedicationRequestResponse(
        id=req.id,
        batch_id=req.batch_id,
        child_id=req.child_id,
        child_name=child_name,
        class_id=req.class_id,
        class_name=class_name,
        parent_id=req.parent_id,
        parent_name=parent_name,
        request_date=req.request_date,
        time_slot=req.time_slot,
        medicine_category=req.medicine_category,
        medicine_name=req.medicine_name,
        dosage=req.dosage,
        notes=req.notes,
        prescription_image_url=req.prescription_image_url,
        status=req.status,
        created_by_user_id=req.created_by_user_id,
        created_by_role=req.created_by_role,
        creator_name=creator_name,
        given_at=req.given_at,
        given_by_id=req.given_by_id,
        given_by_name=given_by_name,
        created_at=req.created_at or now_vn,
        updated_at=req.updated_at or now_vn,
    )


@router.post(
    "",
    response_model=MedicationBatchCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Tạo đơn dặn thuốc (hỗ trợ nhiều cữ và nhiều ngày)",
)
def create_medication_request(
    data: MedicationRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Phụ huynh tạo từ xa hoặc Giáo viên tiếp nhận tạo nhanh tại cửa lớp.
    - parent_id luôn được đảm bảo (không null).
    - Tự động sinh cữ uống theo ngày x khung giờ.
    - Chặn trùng đơn cho cùng cữ uống chưa hủy.
    """
    child = _verify_child_access(db, current_user, data.child_id)

    # Xác định parent_id bắt buộc
    if current_user.role == UserRole.PARENT:
        parent_id = current_user.parent_id
        created_by_role = "parent"
    else:
        # Giáo viên tạo hộ: lấy parent_id từ hồ sơ bé
        parent_id = child.parent_id
        if not parent_id:
            # Fallback sang bảng liên kết parent_child nếu child.parent_id trống
            parent_link = db.scalar(
                select(ParentChild.parent_id).where(ParentChild.child_id == child.child_id)
            )
            parent_id = parent_link
        if not parent_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Học sinh chưa có thông tin phụ huynh liên kết để đối soát đơn thuốc.",
            )
        created_by_role = "teacher"

    # Kiểm tra dải ngày
    start_date = data.from_date
    end_date = data.to_date or data.from_date
    if end_date < start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ngày kết thúc không được trước ngày bắt đầu.",
        )
    if (end_date - start_date).days > 7:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Đợt dặn thuốc tối đa không được vượt quá 7 ngày.",
        )

    # Danh sách các ngày
    date_list: list[date] = []
    curr = start_date
    while curr <= end_date:
        date_list.append(curr)
        curr += timedelta(days=1)

    batch_id = uuid.uuid4()
    created_items: list[MedicationRequest] = []

    for req_date in date_list:
        for slot in data.time_slots:
            # Chặn gửi trùng đơn cữ uống
            existing = db.scalar(
                select(MedicationRequest).where(
                    MedicationRequest.child_id == child.child_id,
                    MedicationRequest.request_date == req_date,
                    MedicationRequest.time_slot == slot,
                    MedicationRequest.status != MedicationStatus.CANCELLED,
                )
            )
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Bé {child.full_name} đã có đơn thuốc lúc {slot} ngày {req_date.strftime('%d/%m/%Y')}.",
                )

            req = MedicationRequest(
                id=uuid.uuid4(),
                batch_id=batch_id,
                child_id=child.child_id,
                parent_id=parent_id,
                class_id=child.class_id,
                request_date=req_date,
                time_slot=slot,
                medicine_category=data.medicine_category,
                medicine_name=data.medicine_name.strip() if data.medicine_name else None,
                dosage=data.dosage.strip(),
                notes=data.notes.strip() if data.notes else None,
                prescription_image_url=data.prescription_image_url.strip(),
                status=MedicationStatus.PENDING,
                created_by_user_id=current_user.user_id,
                created_by_role=created_by_role,
            )
            db.add(req)
            created_items.append(req)

    db.commit()
    for item in created_items:
        db.refresh(item)

    responses = [_to_response(item, db) for item in created_items]
    return MedicationBatchCreateResponse(
        batch_id=batch_id,
        total_slots=len(created_items),
        items=responses,
        message=f"Đã tạo thành công {len(created_items)} cữ uống thuốc cho bé {child.full_name}.",
    )


@router.get(
    "",
    response_model=list[MedicationRequestResponse],
    summary="Xem danh sách cữ dặn thuốc (hỗ trợ lọc theo ngày, bé, lớp, trạng thái)",
)
def list_medication_requests(
    child_id: uuid.UUID | None = None,
    class_id: uuid.UUID | None = None,
    target_date: date | None = Query(None, alias="date"),
    status_filter: MedicationStatus | None = Query(None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Giáo viên xem cữ thuốc theo lớp / ngày; Phụ huynh xem cữ thuốc của con mình.
    """
    stmt = select(MedicationRequest)

    if current_user.role == UserRole.PARENT:
        parent_id = current_user.parent_id
        stmt = stmt.where(MedicationRequest.parent_id == parent_id)
        if child_id:
            stmt = stmt.where(MedicationRequest.child_id == child_id)
    elif current_user.role == UserRole.TEACHER:
        if class_id:
            stmt = stmt.where(MedicationRequest.class_id == class_id)
        elif current_user.teacher_id:
            teacher = db.scalar(
                select(Teacher).where(Teacher.teacher_id == current_user.teacher_id)
            )
            if teacher and teacher.class_id:
                stmt = stmt.where(MedicationRequest.class_id == teacher.class_id)
        if child_id:
            stmt = stmt.where(MedicationRequest.child_id == child_id)

    if target_date:
        stmt = stmt.where(MedicationRequest.request_date == target_date)
    if status_filter:
        stmt = stmt.where(MedicationRequest.status == status_filter)

    stmt = stmt.order_by(
        desc(MedicationRequest.request_date),
        MedicationRequest.time_slot.asc(),
    )
    records = db.scalars(stmt).all()
    return [_to_response(r, db) for r in records]


@router.get(
    "/{request_id}",
    response_model=MedicationRequestResponse,
    summary="Xem chi tiết 1 cữ dặn thuốc",
)
def get_medication_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    req = db.scalar(select(MedicationRequest).where(MedicationRequest.id == request_id))
    if not req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy cữ thuốc yêu cầu.",
        )
    _verify_child_access(db, current_user, req.child_id)
    return _to_response(req, db)


@router.post(
    "/{request_id}/confirm",
    response_model=MedicationRequestResponse,
    summary="Cô giáo xác nhận đã cho bé uống thuốc (chống uống trùng liều)",
)
def confirm_medication_intake(
    request_id: uuid.UUID,
    confirm_data: MedicationConfirmRequest | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Chỉ giáo viên phụ trách mới có quyền xác nhận cữ thuốc.
    Atomic Lock: Chặn trường hợp 2 cô giáo cùng bấm cho uống trùng 1 cữ.
    """
    if current_user.role != UserRole.TEACHER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ giáo viên mới có quyền xác nhận đã cho bé uống thuốc.",
        )

    # Đọc bản ghi với row lock nếu có thể
    req = db.scalar(
        select(MedicationRequest)
        .where(MedicationRequest.id == request_id)
        .with_for_update()
    )
    if not req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy cữ thuốc cần xác nhận.",
        )

    # Kiểm tra trạng thái đã uống chưa (Chống uống trùng liều)
    if req.status == MedicationStatus.GIVEN:
        given_by_name = "Giáo viên khác"
        if req.given_by_id:
            t = db.scalar(select(Teacher).where(Teacher.teacher_id == req.given_by_id))
            if t:
                given_by_name = f"cô {t.full_name}"
        time_str = req.given_at.strftime("%H:%M") if req.given_at else req.time_slot
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cữ thuốc này đã được {given_by_name} cho bé uống lúc {time_str}. Thao tác bị khóa để chống trùng liều.",
        )

    if req.status == MedicationStatus.CANCELLED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cữ thuốc này đã bị phụ huynh hủy.",
        )

    teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
    teacher_id = teacher.teacher_id if teacher else None
    teacher_name = teacher.full_name if teacher else current_user.username

    now_vn = datetime.now(VN_TZ)
    req.status = MedicationStatus.GIVEN
    req.given_at = now_vn
    req.given_by_id = teacher_id
    if confirm_data and confirm_data.notes:
        req.notes = f"{req.notes} | [Cô xác nhận: {confirm_data.notes}]" if req.notes else confirm_data.notes

    db.commit()
    db.refresh(req)

    # Bắn push notification cho phụ huynh của bé
    try:
        tokens = child_parents_device_tokens(db, req.child_id)
        child = req.child or db.scalar(select(Child).where(Child.child_id == req.child_id))
        child_name = child.full_name if child else "bé"
        time_display = req.given_at.strftime("%H:%M")
        title = f"Bé {child_name} đã được uống thuốc"
        body = f"Cô {teacher_name} đã cho bé uống thuốc cữ {req.time_slot} vào lúc {time_display}."
        for dt in tokens:
            try:
                send_push_notification(
                    title=title,
                    body=body,
                    token=dt.token,
                    data={"type": "medication_confirmed", "medication_id": str(req.id)},
                )
            except Exception as push_err:
                logger.warning("Lỗi gửi FCM token: %s", push_err)
    except Exception as fcm_err:
        logger.warning("Lỗi push notification dặn thuốc: %s", fcm_err)

    return _to_response(req, db)


@router.post(
    "/{request_id}/cancel",
    response_model=MedicationRequestResponse,
    summary="Phụ huynh hủy cữ dặn thuốc (chỉ hủy được khi PENDING)",
)
def cancel_medication_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Phụ huynh hủy cữ thuốc. Nếu cô đã cho uống (GIVEN), hệ thống sẽ khóa và báo lỗi 400.
    """
    req = db.scalar(select(MedicationRequest).where(MedicationRequest.id == request_id))
    if not req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy cữ thuốc cần hủy.",
        )

    _verify_child_access(db, current_user, req.child_id)

    if req.status == MedicationStatus.GIVEN:
        time_str = req.given_at.strftime("%H:%M") if req.given_at else req.time_slot
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Không thể hủy đơn vì bé đã được cô giáo cho uống thuốc lúc {time_str}.",
        )

    req.status = MedicationStatus.CANCELLED
    db.commit()
    db.refresh(req)
    return _to_response(req, db)


@router.post(
    "/batch/{batch_id}/cancel",
    summary="Phụ huynh hủy tất cả các cữ còn lại chưa uống của đợt thuốc",
)
def cancel_medication_batch(
    batch_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Hủy nhanh cả đợt thuốc (ví dụ bé khỏi bệnh hoặc đổi đơn thuốc).
    Các cữ đã uống (GIVEN) được giữ nguyên, các cữ PENDING chuyển sang CANCELLED.
    """
    records = db.scalars(
        select(MedicationRequest).where(MedicationRequest.batch_id == batch_id)
    ).all()
    if not records:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy đợt dặn thuốc này.",
        )

    # Kiểm tra quyền sở hữu đối với bé của đợt này
    _verify_child_access(db, current_user, records[0].child_id)

    cancelled_count = 0
    for r in records:
        if r.status == MedicationStatus.PENDING:
            r.status = MedicationStatus.CANCELLED
            cancelled_count += 1

    db.commit()
    return {
        "batch_id": batch_id,
        "cancelled_count": cancelled_count,
        "message": f"Đã hủy thành công {cancelled_count} cữ uống chưa thực hiện của đợt này.",
    }
