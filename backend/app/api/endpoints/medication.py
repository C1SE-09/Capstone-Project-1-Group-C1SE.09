"""
backend/app/api/endpoints/medication.py
=======================================
API Dặn thuốc / Uống thuốc tại lớp cho Giáo viên:
- GET  /api/teacher/medications/today: Lấy danh sách dặn thuốc của lớp hôm nay (chia Sáng/Trưa/Chiều)
- POST /api/teacher/medications/confirm: Xác nhận 1 chạm "Đã cho uống thuốc" (AC1, AC2)
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.config import get_today
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.medication import (
    MedicationLog,
    MedicationRequest,
    MedicationRequestStatus,
    MedicationSession,
)
from app.models.user import Class_, Teacher, User, UserRole
from app.schemas.medication_schema import (
    MedicationConfirmRequest,
    MedicationConfirmResponse,
    MedicationItemResponse,
    MedicationsTodayResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/teacher/medications", tags=["teacher-medications"])


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
# 1. GET /api/teacher/medications/today
# ===========================================================================
@router.get("/today", response_model=MedicationsTodayResponse)
def get_teacher_medications_today(
    class_id: uuid.UUID | None = Query(None, description="ID lớp học (tuỳ chọn với giáo viên)"),
    date_param: date | None = Query(None, alias="date", description="Ngày cần xem (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Lấy danh sách các đơn dặn thuốc đang hoạt động của lớp trong ngày hôm nay:
    - Gom nhóm theo 3 buổi: Sáng (morning), Trưa (noon), Chiều (afternoon).
    - Kèm trạng thái đã cho uống chưa (is_given), cô nào đã cho uống (given_by_name), thời gian (given_at).
    - Cung cấp số điện thoại phụ huynh để cô có thể gọi khẩn cấp (AC3).
    """
    target_class_id = resolve_class_access(current_user, db, class_id)
    target_date = date_param or get_today()

    # Lấy thông tin lớp
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

    # 2. Query lịch sử uống thuốc trong ngày của các đơn này
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

    # Tạo map tra cứu nhanh (request_id, session) -> MedicationLog
    log_map: dict[tuple[uuid.UUID, str], MedicationLog] = {
        (log.request_id, log.session.strip().lower()): log for log in logs
    }

    # 3. Phân nhóm theo Sáng / Trưa / Chiều
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

        # Lấy thông tin phụ huynh để liên lạc khẩn cấp
        parent_phone = None
        parent_name = None
        if req.parent:
            parent_phone = req.parent.phone
            parent_name = req.parent.full_name
        elif child.parents:
            parent_phone = child.parents[0].phone
            parent_name = child.parents[0].full_name

        # Parse danh sách sessions
        req_sessions: list[str] = []
        if isinstance(req.sessions, list):
            req_sessions = [str(s).strip().lower() for s in req.sessions]
        elif isinstance(req.sessions, str):
            req_sessions = [s.strip().lower() for s in req.sessions.split(",")]

        # Mặc định nếu chưa chọn buổi nào thì gán cả 3 buổi
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
# 2. POST /api/teacher/medications/confirm (1-chạm xác nhận đã cho uống thuốc)
# ===========================================================================
@router.post("/confirm", response_model=MedicationConfirmResponse)
def confirm_medication_given(
    payload: MedicationConfirmRequest,
    date_param: date | None = Query(None, alias="date", description="Ngày xác nhận (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Xác nhận 1 chạm 'Đã cho uống thuốc':
    - Lưu giáo viên bấm và thời gian thực tế.
    - Khi cô A bấm, cô B vào lại màn hình sẽ thấy nút bị khoá và hiển thị: 'Cô A đã cho uống lúc [Giờ]'.
    """
    target_date = date_param or get_today()
    normalized_session = payload.session.strip().lower()

    # Kiểm tra đơn dặn thuốc có tồn tại không
    med_req = db.scalar(
        select(MedicationRequest).where(MedicationRequest.request_id == payload.request_id)
    )
    if not med_req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy đơn dặn thuốc",
        )

    # Kiểm tra quyền truy cập lớp học
    resolve_class_access(current_user, db, med_req.class_id)

    # Tìm hoặc tạo bản ghi MedicationLog
    log_entry = db.scalar(
        select(MedicationLog).where(
            MedicationLog.request_id == payload.request_id,
            MedicationLog.log_date == target_date,
            MedicationLog.session == normalized_session,
        )
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
        if payload.notes:
            log_entry.notes = payload.notes
    else:
        log_entry = MedicationLog(
            log_id=uuid.uuid4(),
            request_id=payload.request_id,
            log_date=target_date,
            session=normalized_session,
            is_given=True,
            given_by_id=current_user.teacher_id,
            given_at=now_utc,
            notes=payload.notes,
        )
        db.add(log_entry)

    db.commit()
    db.refresh(log_entry)

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
