"""Quyền và chuyển trạng thái thuốc dùng chung cho API cũ/mới, khóa tại DB."""

import uuid
from datetime import date, datetime, time, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, lazyload

from app.config import get_today, vn_tz
from app.core.access import resolve_child_for_actor, role_of
from app.models.child import Child, ChildStatus
from app.models.medication import MedicationLog, MedicationRequest, MedicationRequestStatus as State
from app.models.user import Teacher, User


def resolve_class_access(user: User, db: Session, requested_class_id: uuid.UUID | None = None) -> uuid.UUID:
    role = role_of(user)
    if role == "admin":
        if not requested_class_id:
            raise HTTPException(400, "Tài khoản Admin vui lòng truyền tham số class_id")
        return requested_class_id
    if role != "teacher" or not user.teacher_id:
        raise HTTPException(403, "Chức năng này chỉ dành cho Giáo viên và Quản trị viên")
    teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == user.teacher_id)
                        .execution_options(populate_existing=True))
    if not teacher:
        raise HTTPException(403, "Không tìm thấy thông tin giáo viên trong hệ thống")
    if requested_class_id and teacher.class_id != requested_class_id:
        raise HTTPException(403, "Bạn không có quyền truy cập dữ liệu dặn thuốc của lớp học này")
    if not teacher.class_id:
        raise HTTPException(400, "Giáo viên chưa được phân công lớp chủ nhiệm")
    return teacher.class_id


def resolve_medication_child(db: Session, user: User, child_id: uuid.UUID, *, require_enrolled: bool = False) -> Child:
    if role_of(user) == "teacher":
        resolve_class_access(user, db)
    child = db.scalar(select(Child).options(lazyload("*")).where(Child.child_id == child_id)
                      .execution_options(populate_existing=True))
    if child is None:
        raise HTTPException(404, "Không tìm thấy học sinh")
    resolve_child_for_actor(db, child_id, user)
    if require_enrolled and child.status != ChildStatus.ENROLLED:
        raise HTTPException(404, "Không tìm thấy học sinh hoặc bé đã thôi học")
    return child


def medication_session(time_slot: str) -> str:
    try:
        value = time.fromisoformat(time_slot)
        if value.tzinfo is not None:
            raise ValueError
    except ValueError:
        raise HTTPException(422, "Khung giờ uống thuốc không hợp lệ") from None
    return "morning" if value < time(11) else "noon" if value < time(14) else "afternoon"


def aware_timestamp(value: datetime | None) -> datetime | None:
    # SQLite không giữ tzinfo; mọi thời điểm ghi mới đều là UTC.
    return value.replace(tzinfo=timezone.utc) if value is not None and value.tzinfo is None else value


def dose_audit(req: MedicationRequest) -> MedicationLog | None:
    """Đọc log đã có từ API cũ, không tự sửa DB hay tạo giờ/actor giả."""
    if req.time_slot is None or req.request_date is None:
        return None
    session = medication_session(req.time_slot)
    return next((log for log in req.logs if log.log_date == req.request_date
                 and log.session == session and log.is_given), None)


def _locked(db: Session, request_id: uuid.UUID) -> MedicationRequest:
    # SQLAlchemy 2.0: tránh joined eager loading + FOR UPDATE, refresh identity map.
    # https://docs.sqlalchemy.org/en/20/orm/queryguide/api.html#populate-existing
    req = db.scalar(select(MedicationRequest).options(lazyload("*"))
                    .where(MedicationRequest.request_id == request_id)
                    .with_for_update(of=MedicationRequest).execution_options(populate_existing=True))
    if req is None:
        raise HTTPException(404, "Không tìm thấy đơn dặn thuốc")
    return req


def verify_medication_access(db: Session, req: MedicationRequest, user: User, *, confirming: bool = False) -> None:
    if role_of(user) == "teacher":
        resolve_class_access(user, db, req.class_id)
    stmt = select(Child).options(lazyload("*")).where(Child.child_id == req.child_id)
    if confirming:
        stmt = stmt.with_for_update(of=Child)
    child = db.scalar(stmt.execution_options(populate_existing=True))
    if confirming and (child is None or child.status != ChildStatus.ENROLLED or child.class_id != req.class_id):
        raise HTTPException(409, "Hồ sơ bé đã thay đổi, vui lòng kiểm tra lại lớp và đơn thuốc")
    resolve_child_for_actor(db, req.child_id, user)


def _already_given(req: MedicationRequest, log: MedicationLog | None) -> HTTPException:
    teacher = log.given_by if log else req.teacher
    name = teacher.full_name if teacher else "giáo viên khác"
    actor = name if name.lower().startswith("cô ") else f"cô {name}"
    given_at = aware_timestamp(log.given_at if log else req.given_at)
    stamp = given_at.astimezone(vn_tz).strftime("%H:%M") if given_at else "chưa rõ thời điểm"
    return HTTPException(409, f"Cảnh báo trùng liều: Cữ thuốc này đã được {actor} cho bé uống thuốc lúc {stamp} rồi!")


def confirm_medication(
    db: Session, request_id: uuid.UUID, user: User, *, target_date: date | None = None,
    session: str | None = None, notes: str | None = None,
) -> tuple[MedicationRequest, MedicationLog]:
    if role_of(user) not in {"teacher", "admin"}:
        raise HTTPException(403, "Chỉ giáo viên mới có quyền xác nhận đã cho bé uống thuốc")
    if session is not None:
        session = session.strip().lower()
        if session not in {"morning", "noon", "afternoon"}:
            raise HTTPException(400, "Buổi uống không hợp lệ: chỉ chấp nhận morning, noon, afternoon")
    req = _locked(db, request_id)
    verify_medication_access(db, req, user, confirming=True)
    if req.status in {State.CANCELLED, State.COMPLETED}:
        raise HTTPException(400, "Đơn thuốc đã hủy hoặc kết thúc, không thể xác nhận")
    is_slot = req.time_slot is not None and req.request_date is not None
    if is_slot:
        expected_session = medication_session(req.time_slot)
        if ((target_date is not None and target_date != req.request_date)
                or (session is not None and session != expected_session)):
            raise HTTPException(400, "Ngày hoặc buổi không khớp cữ thuốc")
        target_date, session = req.request_date, expected_session
    else:
        target_date = target_date or get_today()
        sessions = req.sessions if isinstance(req.sessions, list) else (req.sessions or "").split(",")
        if (req.status != State.ACTIVE or session is None or not req.start_date <= target_date <= req.end_date
                or (sessions and session not in {item.strip().lower() for item in sessions})):
            raise HTTPException(400, "Ngày hoặc buổi không thuộc lịch thuốc đang có hiệu lực")
    log = db.scalar(select(MedicationLog).where(
        MedicationLog.request_id == request_id, MedicationLog.log_date == target_date,
        MedicationLog.session == session,
    ).execution_options(populate_existing=True))
    if req.status == State.GIVEN or (log and log.is_given):
        raise _already_given(req, log if log and log.is_given else None)
    if log is None:
        log = MedicationLog(log_id=uuid.uuid4(), request_id=request_id, log_date=target_date, session=session)
        db.add(log)
    now = datetime.now(timezone.utc)
    log.is_given, log.given_by_id, log.given_at = True, user.teacher_id, now
    if notes:
        log.notes = notes
    if is_slot:
        req.status, req.given_by_id, req.given_at = State.GIVEN, user.teacher_id, now
    db.commit()
    db.refresh(req)
    db.refresh(log)
    return req, log


def cancel_medication(db: Session, request_id: uuid.UUID, user: User) -> MedicationRequest:
    req = _locked(db, request_id)
    verify_medication_access(db, req, user)
    if req.status == State.GIVEN or dose_audit(req):
        raise HTTPException(400, "Không thể hủy đơn vì bé đã được cô giáo cho uống thuốc")
    if req.status == State.COMPLETED:
        raise HTTPException(400, "Đợt thuốc đã kết thúc, không thể hủy")
    req.status = State.CANCELLED
    db.commit()
    db.refresh(req)
    return req


def cancel_medication_batch(db: Session, batch_id: uuid.UUID, user: User) -> int:
    requests = db.scalars(select(MedicationRequest).options(lazyload("*"))
                          .where(MedicationRequest.batch_id == batch_id).order_by(MedicationRequest.request_id)
                          .with_for_update(of=MedicationRequest).execution_options(populate_existing=True)).all()
    if not requests:
        raise HTTPException(404, "Không tìm thấy đợt dặn thuốc này")
    for req in requests:
        verify_medication_access(db, req, user)
    count = 0
    for req in requests:
        if req.status in {State.PENDING, State.ACTIVE} and not dose_audit(req):
            req.status = State.CANCELLED
            count += 1
    db.commit()
    return count
