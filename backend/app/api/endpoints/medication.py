"""
backend/app/api/endpoints/medication.py
=======================================
API Dặn thuốc / Uống thuốc tại lớp cho Giáo viên & Phụ huynh:
- Task #283: GET /api/teacher/medications/today: Lấy danh sách dặn thuốc của lớp hôm nay (chia Sáng/Trưa/Chiều)
- Task #284: POST / PUT /api/teacher/medications/confirm: Xác nhận 1 chạm "Đã cho uống thuốc"
- User Story 3.1: POST /api/medication-requests: Tạo đơn dặn thuốc đa cữ, dài ngày & ảnh đơn thuốc
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.orm import Session, joinedload

from app.config import get_today
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ChildStatus, Parent, ParentChild
from app.models.medication import (
    MedicationLog,
    MedicationRequest,
    MedicationRequestStatus,
    MedicationSession,
    MedicationStatus,
    MedicineCategory,
)
from app.models.user import Class_, Teacher, User, UserRole
from app.schemas.medication_schema import (
    MedicationBatchCreateResponse,
    MedicationConfirmPayload,
    MedicationConfirmRequest,
    MedicationConfirmResponse,
    MedicationItemResponse,
    MedicationRequestCreate,
    MedicationRequestResponse,
    MedicationsTodayResponse,
)
from app.tasks.medication_notifications import (
    SESSION_LABELS,
    deliver_medication_notification_sync,
    send_medication_confirmed_notification,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["medication"])

VN_TZ = ZoneInfo("Asia/Ho_Chi_Minh")


# ===========================================================================
# 1. PHÂN QUYỀN TRUY CẬP LỚP CHO GIÁO VIÊN (Task #283)
# ===========================================================================
def resolve_class_access(
    current_user: User,
    db: Session,
    requested_class_id: uuid.UUID | None = None,
) -> uuid.UUID:
    """
    Xác định class_id hợp lệ dựa trên quyền của người dùng:
    - Admin: Có thể chỉ định class_id bất kỳ.
    - Teacher: Tự động dùng lớp chủ nhiệm của cô, hoặc kiểm tra quyền nếu có truyền class_id.
    """
    role_val = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)

    if role_val == UserRole.ADMIN.value:
        if not requested_class_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tài khoản Admin vui lòng truyền tham số class_id",
            )
        return requested_class_id

    if role_val == UserRole.TEACHER.value:
        if not current_user.teacher_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tài khoản giáo viên chưa được liên kết với thông tin nhân sự",
            )

        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Không tìm thấy thông tin giáo viên trong hệ thống",
            )

        if requested_class_id:
            if teacher.class_id != requested_class_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Bạn không có quyền truy cập dữ liệu dặn thuốc của lớp học này",
                )
            return requested_class_id

        if not teacher.class_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Giáo viên chưa được phân công lớp chủ nhiệm",
            )
        return teacher.class_id

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Chức năng này chỉ dành cho Giáo viên và Quản trị viên",
    )


# ===========================================================================
# 2. GET /api/teacher/medications/today (Task #283)
# ===========================================================================
@router.get("/teacher/medications/today", response_model=MedicationsTodayResponse)
def get_teacher_medications_today(
    class_id: uuid.UUID | None = Query(None, description="ID lớp học (tuỳ chọn với giáo viên)"),
    date_param: date | None = Query(None, alias="date", description="Ngày cần xem (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Lấy danh sách các đơn dặn thuốc đang hoạt động của lớp trong ngày hôm nay:
    - Gom nhóm theo 3 buổi: Sáng (morning), Trưa (noon), Chiều (afternoon).
    """
    target_class_id = resolve_class_access(current_user, db, class_id)
    target_date = date_param or get_today()

    class_info = db.scalar(select(Class_).where(Class_.class_id == target_class_id))
    class_name = class_info.name if class_info else None

    # 1. Query các đơn dặn thuốc đang active của lớp trong ngày target_date
    requests = db.scalars(
        select(MedicationRequest)
        .options(
            joinedload(MedicationRequest.child),
            joinedload(MedicationRequest.parent),
        )
        .where(
            MedicationRequest.class_id == target_class_id,
            MedicationRequest.status == MedicationRequestStatus.ACTIVE,
            MedicationRequest.start_date <= target_date,
            MedicationRequest.end_date >= target_date,
        )
        .order_by(MedicationRequest.created_at.asc())
    ).all()

    request_ids = [r.request_id for r in requests]
    logs: list[MedicationLog] = []
    if request_ids:
        logs = list(
            db.scalars(
                select(MedicationLog)
                .options(joinedload(MedicationLog.given_by))
                .where(
                    MedicationLog.request_id.in_(request_ids),
                    MedicationLog.log_date == target_date,
                )
            ).all()
        )

    log_map: dict[tuple[uuid.UUID, str], MedicationLog] = {
        (log.request_id, log.session.strip().lower()): log for log in logs
    }

    morning_items: list[MedicationItemResponse] = []
    noon_items: list[MedicationItemResponse] = []
    afternoon_items: list[MedicationItemResponse] = []

    completed_count = 0
    pending_count = 0

    session_buckets = {
        MedicationSession.MORNING.value: morning_items,
        MedicationSession.NOON.value: noon_items,
        MedicationSession.AFTERNOON.value: afternoon_items,
    }

    for req in requests:
        child = req.child
        if not child:
            continue

        parent_phone = None
        parent_name = None
        if req.parent:
            parent_phone = req.parent.phone
            parent_name = req.parent.full_name
        elif hasattr(child, "parents") and child.parents:
            parent_phone = child.parents[0].phone
            parent_name = child.parents[0].full_name

        req_sessions: list[str] = []
        if isinstance(req.sessions, list):
            req_sessions = [str(s).strip().lower() for s in req.sessions]
        elif isinstance(req.sessions, str):
            req_sessions = [s.strip().lower() for s in req.sessions.split(",")]

        if not req_sessions:
            req_sessions = [
                MedicationSession.MORNING.value,
                MedicationSession.NOON.value,
                MedicationSession.AFTERNOON.value,
            ]

        for sess_key in [
            MedicationSession.MORNING.value,
            MedicationSession.NOON.value,
            MedicationSession.AFTERNOON.value,
        ]:
            if sess_key in req_sessions:
                log_entry = log_map.get((req.request_id, sess_key))
                is_given = log_entry.is_given if log_entry else False
                given_at = log_entry.given_at if log_entry else None
                given_by_id = log_entry.given_by_id if log_entry else None
                given_by_name = (
                    log_entry.given_by.full_name
                    if (log_entry and log_entry.given_by)
                    else None
                )

                if is_given:
                    completed_count += 1
                else:
                    pending_count += 1

                item = MedicationItemResponse(
                    request_id=req.request_id,
                    child_id=child.child_id,
                    child_name=child.full_name,
                    child_nickname=child.nickname,
                    child_avatar_url=child.avatar_url,
                    medication_name=req.medication_name,
                    dosage=req.dosage,
                    instructions=req.instructions,
                    session=sess_key,
                    is_given=is_given,
                    given_at=given_at,
                    given_by_id=given_by_id,
                    given_by_name=given_by_name,
                    notes=log_entry.notes if log_entry else req.notes,
                    parent_name=parent_name,
                    parent_phone=parent_phone,
                )
                session_buckets[sess_key].append(item)

    total_requests = completed_count + pending_count

    return MedicationsTodayResponse(
        date=target_date,
        class_id=target_class_id,
        class_name=class_name,
        total_requests=total_requests,
        completed_count=completed_count,
        pending_count=pending_count,
        morning=morning_items,
        noon=noon_items,
        afternoon=afternoon_items,
    )


# ===========================================================================
# 3. XỬ LÝ XÁC NHẬN CHO UỐNG THUỐC (Task #284)
# ===========================================================================
def process_medication_confirmation(
    request_id: uuid.UUID,
    session_str: str,
    notes: str | None,
    target_date: date,
    current_user: User,
    db: Session,
    background_tasks: BackgroundTasks,
) -> MedicationConfirmResponse:
    normalized_session = session_str.strip().lower()
    valid_sessions = {
        MedicationSession.MORNING.value,
        MedicationSession.NOON.value,
        MedicationSession.AFTERNOON.value,
    }
    if normalized_session not in valid_sessions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Buổi uống không hợp lệ: '{session_str}'. Chỉ chấp nhận 'morning', 'noon', 'afternoon'.",
        )

    med_req = db.scalar(
        select(MedicationRequest).where(MedicationRequest.request_id == request_id)
    )
    if not med_req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy đơn dặn thuốc",
        )

    resolve_class_access(current_user, db, med_req.class_id)

    stmt = (
        select(MedicationLog)
        .options(joinedload(MedicationLog.given_by))
        .where(
            MedicationLog.request_id == request_id,
            MedicationLog.log_date == target_date,
            MedicationLog.session == normalized_session,
        )
    )
    try:
        if db.bind and "sqlite" not in str(db.bind.dialect.name).lower():
            stmt = stmt.with_for_update()
    except Exception:
        pass

    log_entry = db.scalar(stmt)

    if log_entry and log_entry.is_given:
        already_teacher = log_entry.given_by.full_name if log_entry.given_by else "giáo viên khác"
        vn_tz = timezone(timedelta(hours=7))
        time_str = log_entry.given_at.astimezone(vn_tz).strftime("%H:%M") if log_entry.given_at else ""
        session_vn = SESSION_LABELS.get(normalized_session, normalized_session)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Cảnh báo trùng liều: Bé đã được {already_teacher} cho uống thuốc buổi {session_vn} "
                f"lúc {time_str} rồi! Nút đã bị khoá để bảo vệ an toàn cho bé."
            ),
        )

    now_utc = datetime.now(timezone.utc)
    teacher_name = None

    if current_user.teacher_id:
        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
        teacher_name = teacher.full_name if teacher else current_user.username
    else:
        teacher_name = current_user.username

    if log_entry:
        log_entry.is_given = True
        log_entry.given_by_id = current_user.teacher_id
        log_entry.given_at = now_utc
        if notes:
            log_entry.notes = notes
    else:
        log_entry = MedicationLog(
            log_id=uuid.uuid4(),
            request_id=med_req.request_id,
            log_date=target_date,
            session=normalized_session,
            is_given=True,
            given_by_id=current_user.teacher_id,
            given_at=now_utc,
            notes=notes,
        )
        db.add(log_entry)

    db.commit()
    db.refresh(log_entry)

    try:
        send_medication_confirmed_notification.delay(
            str(med_req.request_id),
            str(log_entry.log_id),
        )
    except Exception as exc:
        logger.info(
            "[Medication] Celery worker không sẵn sàng, dispatch qua FastAPI BackgroundTasks: %s",
            exc,
        )
        background_tasks.add_task(
            deliver_medication_notification_sync,
            str(med_req.request_id),
            str(log_entry.log_id),
        )

    return MedicationConfirmResponse(
        success=True,
        message=f"{teacher_name} đã xác nhận cho bé uống thuốc thành công",
        log_id=log_entry.log_id,
        request_id=med_req.request_id,
        session=normalized_session,
        is_given=log_entry.is_given,
        given_by_name=teacher_name,
        given_at=log_entry.given_at or now_utc,
    )


@router.put("/teacher/medications/{request_id}/confirm", response_model=MedicationConfirmResponse)
def confirm_medication_put(
    request_id: uuid.UUID,
    payload: MedicationConfirmPayload,
    background_tasks: BackgroundTasks,
    date_param: date | None = Query(None, alias="date", description="Ngày xác nhận (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_date = date_param or get_today()
    return process_medication_confirmation(
        request_id=request_id,
        session_str=payload.session,
        notes=payload.notes,
        target_date=target_date,
        current_user=current_user,
        db=db,
        background_tasks=background_tasks,
    )


@router.post("/teacher/medications/confirm", response_model=MedicationConfirmResponse)
def confirm_medication_post(
    payload: MedicationConfirmRequest,
    background_tasks: BackgroundTasks,
    date_param: date | None = Query(None, alias="date", description="Ngày xác nhận (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not payload.request_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Thiếu request_id trong nội dung yêu cầu",
        )
    target_date = date_param or get_today()
    return process_medication_confirmation(
        request_id=payload.request_id,
        session_str=payload.session,
        notes=payload.notes,
        target_date=target_date,
        current_user=current_user,
        db=db,
        background_tasks=background_tasks,
    )


# ===========================================================================
# 4. USER STORY 3.1: DẶN THUỐC & THEO DÕI HỒ SƠ Y TẾ
# ===========================================================================
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
    child = req.child or db.scalar(select(Child).where(Child.child_id == req.child_id))
    child_name = child.full_name if child else "Học sinh"

    class_name = None
    if req.class_id:
        class_ = req.class_ or db.scalar(select(Class_).where(Class_.class_id == req.class_id))
        class_name = class_.name if class_ else None

    parent = req.parent or (db.scalar(select(Parent).where(Parent.parent_id == req.parent_id)) if req.parent_id else None)
    parent_name = parent.full_name if parent else None

    creator_name = "Người dùng"
    if req.created_by_role == "parent":
        creator_name = parent_name or "Phụ huynh"
    elif req.created_by_role == "teacher":
        creator_user = req.created_by_user or (
            db.scalar(select(User).where(User.user_id == req.created_by_user_id))
            if req.created_by_user_id
            else None
        )
        if creator_user and creator_user.teacher_id:
            t = db.scalar(select(Teacher).where(Teacher.teacher_id == creator_user.teacher_id))
            creator_name = t.full_name if t else creator_user.username
        else:
            creator_name = creator_user.username if creator_user else "Giáo viên"

    given_by_name = None
    if req.given_by_id:
        t = req.teacher or db.scalar(select(Teacher).where(Teacher.teacher_id == req.given_by_id))
        given_by_name = t.full_name if t else None

    now_vn = datetime.now(VN_TZ)
    return MedicationRequestResponse(
        id=req.request_id,
        batch_id=req.batch_id or req.request_id,
        child_id=req.child_id,
        child_name=child_name,
        class_id=req.class_id,
        class_name=class_name,
        parent_id=req.parent_id or uuid.UUID("00000000-0000-0000-0000-000000000000"),
        parent_name=parent_name,
        request_date=req.request_date or req.start_date,
        time_slot=req.time_slot or "08:30",
        medicine_category=req.medicine_category or MedicineCategory.PRESCRIPTION,
        medicine_name=req.medication_name,
        dosage=req.dosage,
        notes=req.notes,
        prescription_image_url=req.prescription_image_url or "",
        status=req.status,
        created_by_user_id=req.created_by_user_id or uuid.uuid4(),
        created_by_role=req.created_by_role or "parent",
        creator_name=creator_name,
        given_at=req.given_at,
        given_by_id=req.given_by_id,
        given_by_name=given_by_name,
        created_at=req.created_at or now_vn,
        updated_at=req.updated_at or now_vn,
    )


@router.post(
    "/medication-requests",
    response_model=MedicationBatchCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Tạo đơn dặn thuốc (hỗ trợ nhiều cữ và nhiều ngày)",
)
def create_medication_request(
    data: MedicationRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    child = _verify_child_access(db, current_user, data.child_id)

    if current_user.role == UserRole.PARENT:
        parent_id = current_user.parent_id
        created_by_role = "parent"
    else:
        parent_id = child.parent_id
        if not parent_id:
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

    date_list: list[date] = []
    curr = start_date
    while curr <= end_date:
        date_list.append(curr)
        curr += timedelta(days=1)

    batch_id = uuid.uuid4()
    created_items: list[MedicationRequest] = []

    for req_date in date_list:
        for slot in data.time_slots:
            existing = db.scalar(
                select(MedicationRequest).where(
                    MedicationRequest.child_id == child.child_id,
                    MedicationRequest.request_date == req_date,
                    MedicationRequest.time_slot == slot,
                    MedicationRequest.status != MedicationRequestStatus.CANCELLED,
                )
            )
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Bé {child.full_name} đã có đơn thuốc lúc {slot} ngày {req_date.strftime('%d/%m/%Y')}.",
                )

            req = MedicationRequest(
                request_id=uuid.uuid4(),
                batch_id=batch_id,
                child_id=child.child_id,
                parent_id=parent_id,
                class_id=child.class_id,
                start_date=req_date,
                end_date=req_date,
                request_date=req_date,
                time_slot=slot,
                medicine_category=data.medicine_category,
                medication_name=data.medicine_name.strip() if data.medicine_name else "Thuốc theo đơn",
                dosage=data.dosage.strip(),
                notes=data.notes.strip() if data.notes else None,
                prescription_image_url=data.prescription_image_url.strip(),
                status=MedicationRequestStatus.PENDING,
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
    "/medication-requests",
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
        stmt = stmt.where(
            (MedicationRequest.request_date == target_date)
            | (
                (MedicationRequest.start_date <= target_date)
                & (MedicationRequest.end_date >= target_date)
            )
        )
    if status_filter:
        stmt = stmt.where(MedicationRequest.status == status_filter)

    stmt = stmt.order_by(
        desc(MedicationRequest.created_at),
    )
    records = db.scalars(stmt).all()
    return [_to_response(r, db) for r in records]


@router.get(
    "/medication-requests/{request_id}",
    response_model=MedicationRequestResponse,
    summary="Xem chi tiết 1 cữ dặn thuốc",
)
def get_medication_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    req = db.scalar(select(MedicationRequest).where(MedicationRequest.request_id == request_id))
    if not req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy cữ thuốc yêu cầu.",
        )
    _verify_child_access(db, current_user, req.child_id)
    return _to_response(req, db)


class MedicationRequestConfirmInput(BaseModel):
    session: str | None = None
    notes: str | None = None


@router.post(
    "/medication-requests/{request_id}/confirm",
    response_model=MedicationRequestResponse,
    summary="Cô giáo xác nhận đã cho bé uống thuốc (chống uống trùng liều)",
)
def confirm_medication_request_intake(
    request_id: uuid.UUID,
    confirm_data: MedicationRequestConfirmInput | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.TEACHER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ giáo viên mới có quyền xác nhận đã cho bé uống thuốc.",
        )

    req = db.scalar(
        select(MedicationRequest)
        .where(MedicationRequest.request_id == request_id)
    )
    if not req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy cữ thuốc cần xác nhận.",
        )

    if req.status == MedicationRequestStatus.GIVEN:
        given_by_name = "Giáo viên khác"
        if req.given_by_id:
            t = db.scalar(select(Teacher).where(Teacher.teacher_id == req.given_by_id))
            if t:
                given_by_name = f"cô {t.full_name}"
        time_str = req.given_at.strftime("%H:%M") if req.given_at else req.time_slot or ""
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cữ thuốc này đã được {given_by_name} cho bé uống lúc {time_str}. Thao tác bị khóa để chống trùng liều.",
        )

    if req.status == MedicationRequestStatus.CANCELLED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cữ thuốc này đã bị phụ huynh hủy.",
        )

    teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
    teacher_id = teacher.teacher_id if teacher else None

    now_vn = datetime.now(VN_TZ)
    req.status = MedicationRequestStatus.GIVEN
    req.given_at = now_vn
    req.given_by_id = teacher_id
    if confirm_data and confirm_data.notes:
        req.notes = f"{req.notes} | [Cô xác nhận: {confirm_data.notes}]" if req.notes else confirm_data.notes

    db.commit()
    db.refresh(req)

    return _to_response(req, db)


@router.post(
    "/medication-requests/{request_id}/cancel",
    response_model=MedicationRequestResponse,
    summary="Phụ huynh hủy cữ dặn thuốc (chỉ hủy được khi PENDING)",
)
def cancel_medication_request(
    request_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    req = db.scalar(select(MedicationRequest).where(MedicationRequest.request_id == request_id))
    if not req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy cữ thuốc cần hủy.",
        )

    _verify_child_access(db, current_user, req.child_id)

    if req.status == MedicationRequestStatus.GIVEN:
        time_str = req.given_at.strftime("%H:%M") if req.given_at else req.time_slot or ""
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Không thể hủy đơn vì bé đã được cô giáo cho uống thuốc lúc {time_str}.",
        )

    req.status = MedicationRequestStatus.CANCELLED
    db.commit()
    db.refresh(req)
    return _to_response(req, db)


@router.post(
    "/medication-requests/batch/{batch_id}/cancel",
    summary="Phụ huynh hủy tất cả các cữ còn lại chưa uống của đợt thuốc",
)
def cancel_medication_batch(
    batch_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    records = db.scalars(
        select(MedicationRequest).where(MedicationRequest.batch_id == batch_id)
    ).all()
    if not records:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy đợt dặn thuốc này.",
        )

    _verify_child_access(db, current_user, records[0].child_id)

    cancelled_count = 0
    for r in records:
        if r.status in [MedicationRequestStatus.PENDING, MedicationRequestStatus.ACTIVE]:
            r.status = MedicationRequestStatus.CANCELLED
            cancelled_count += 1

    db.commit()
    return {
        "batch_id": batch_id,
        "cancelled_count": cancelled_count,
        "message": f"Đã hủy thành công {cancelled_count} cữ uống chưa thực hiện của đợt này.",
    }
