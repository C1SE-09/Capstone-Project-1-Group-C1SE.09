"""
app/services/schedule_service.py
================================
Nghiệp vụ (Service Layer) cho quản lý Thời khóa biểu (TimeSlot, Subject, ClassSchedule).
"""

from __future__ import annotations

from datetime import UTC, datetime
import uuid

from app.models.schedule import ClassSchedule, Subject, TimeSlot
from app.schemas.schedule import (
    ClassScheduleBulkCreateItem,
    ClassScheduleCreate,
    ClassScheduleUpdate,
    SubjectCreate,
    SubjectUpdate,
    TimeSlotCreate,
    TimeSlotUpdate,
)
from sqlalchemy.orm import Session, joinedload


# ===========================================================================
# TimeSlot Services
# ===========================================================================
def get_all_time_slots(db: Session) -> list[TimeSlot]:
    return db.query(TimeSlot).order_by(TimeSlot.order_index.asc()).all()


def get_time_slot_by_id(db: Session, slot_id: uuid.UUID) -> TimeSlot | None:
    return db.query(TimeSlot).filter(TimeSlot.slot_id == slot_id).first()


def create_time_slot(db: Session, data: TimeSlotCreate) -> TimeSlot:
    slot = TimeSlot(
        slot_id=uuid.uuid4(),
        name=data.name,
        start_time=data.start_time,
        end_time=data.end_time,
        order_index=data.order_index,
    )
    db.add(slot)
    db.commit()
    db.refresh(slot)
    return slot


def update_time_slot(
    db: Session, slot_id: uuid.UUID, data: TimeSlotUpdate
) -> TimeSlot | None:
    slot = get_time_slot_by_id(db, slot_id)
    if not slot:
        return None

    update_dict = data.model_dump(exclude_unset=True)
    for field, value in update_dict.items():
        setattr(slot, field, value)

    db.commit()
    db.refresh(slot)
    return slot


def delete_time_slot(db: Session, slot_id: uuid.UUID) -> bool:
    slot = get_time_slot_by_id(db, slot_id)
    if not slot:
        return False
    db.delete(slot)
    db.commit()
    return True


# ===========================================================================
# Subject Services
# ===========================================================================
def get_all_subjects(db: Session) -> list[Subject]:
    return db.query(Subject).order_by(Subject.name.asc()).all()


def get_subject_by_id(db: Session, subject_id: uuid.UUID) -> Subject | None:
    return db.query(Subject).filter(Subject.subject_id == subject_id).first()


def create_subject(db: Session, data: SubjectCreate) -> Subject:
    subject = Subject(
        subject_id=uuid.uuid4(),
        name=data.name,
        code=data.code,
        color_code=data.color_code,
        description=data.description,
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)
    return subject


def update_subject(
    db: Session, subject_id: uuid.UUID, data: SubjectUpdate
) -> Subject | None:
    subject = get_subject_by_id(db, subject_id)
    if not subject:
        return None

    update_dict = data.model_dump(exclude_unset=True)
    for field, value in update_dict.items():
        setattr(subject, field, value)

    db.commit()
    db.refresh(subject)
    return subject


def delete_subject(db: Session, subject_id: uuid.UUID) -> bool:
    subject = get_subject_by_id(db, subject_id)
    if not subject:
        return False
    db.delete(subject)
    db.commit()
    return True


# ===========================================================================
# Time Validation, Effective Times & Resolution Helpers (Shared)
# ===========================================================================
WORKING_HOURS_START_MIN = 7 * 60
WORKING_HOURS_END_MIN = 17 * 60


def parse_hhmm(value: str) -> tuple[str, int]:
    """Parse HH:MM (or H:MM) into normalized 'HH:MM' and minutes since midnight."""
    if not isinstance(value, str):
        raise ValueError("Định dạng giờ không hợp lệ (yêu cầu HH:MM).")
    clean = value.strip()
    parts = clean.split(":")
    if len(parts) != 2 or not parts[0].isdigit() or not parts[1].isdigit():
        raise ValueError(f"Định dạng giờ không hợp lệ ({clean}), yêu cầu HH:MM.")
    hh = int(parts[0])
    mm = int(parts[1])
    if hh < 0 or hh > 23 or mm < 0 or mm > 59:
        raise ValueError(f"Giá trị giờ không hợp lệ ({clean}).")
    return f"{hh:02d}:{mm:02d}", hh * 60 + mm


def to_minutes(value: str | None) -> int:
    """Convert HH:MM string to minutes since midnight; returns 0 on invalid/None."""
    if not value or not isinstance(value, str):
        return 0
    try:
        return parse_hhmm(value)[1]
    except ValueError:
        return 0


def validate_time_range(
    start_time: str,
    end_time: str,
    *,
    enforce_working_hours: bool = True,
) -> tuple[str, str]:
    """Validate and normalize start/end times and enforce ordering + working hours."""
    st, st_min = parse_hhmm(start_time)
    et, et_min = parse_hhmm(end_time)
    if et_min <= st_min:
        raise ValueError(
            f"Khung giờ không hợp lệ: Giờ kết thúc ({et}) phải sau giờ bắt đầu ({st})."
        )
    if enforce_working_hours and (
        st_min < WORKING_HOURS_START_MIN or et_min > WORKING_HOURS_END_MIN
    ):
        raise ValueError(
            f"Khung giờ ({st} - {et}) nằm ngoài giờ làm việc của trường (chỉ cho phép từ 07:00 đến 17:00 - hết giờ trả trẻ)."
        )
    return st, et


def get_schedule_effective_times(schedule: ClassSchedule) -> tuple[str, str]:
    """Return effective (start_time, end_time) preferring custom times over time_slot."""
    custom_start = getattr(schedule, "custom_start_time", None)
    custom_end = getattr(schedule, "custom_end_time", None)
    if (
        isinstance(custom_start, str)
        and custom_start
        and isinstance(custom_end, str)
        and custom_end
    ):
        return custom_start, custom_end

    time_slot = getattr(schedule, "time_slot", None)
    if time_slot is not None:
        st = getattr(time_slot, "start_time", None)
        et = getattr(time_slot, "end_time", None)
        if isinstance(st, str) and st and isinstance(et, str) and et:
            return st, et

    return "07:00", "08:00"


def schedule_sort_key(
    schedule: ClassSchedule, *, include_day: bool = True
) -> tuple[int, ... | float]:
    """Build chronological sort key across standard slots and custom-time entries."""
    st, et = get_schedule_effective_times(schedule)
    created = getattr(schedule, "created_at", None)
    if isinstance(created, datetime):
        if created.tzinfo is None:
            created = created.replace(tzinfo=UTC)
        created_ts = created.timestamp()
    else:
        created_ts = 0.0

    day = schedule.day_of_week if isinstance(schedule.day_of_week, int) else 0
    if include_day:
        return (day, to_minutes(st), to_minutes(et), created_ts)
    return (to_minutes(st), to_minutes(et), created_ts)


def resolve_schedule_time_selection(
    db: Session,
    slot_id: str | uuid.UUID | None,
    start_time: str | None,
    end_time: str | None,
    *,
    enforce_working_hours: bool = True,
    fallback_to_first_slot: bool = False,
) -> tuple[TimeSlot | None, str | None, str | None]:
    """Resolve schedule timing to either an existing TimeSlot or custom start/end times.

    Never inserts rows into `time_slot` when custom hours do not match an existing slot.
    """
    parsed_slot_uuid: uuid.UUID | None = None
    if isinstance(slot_id, uuid.UUID):
        parsed_slot_uuid = slot_id
    elif isinstance(slot_id, str) and slot_id.strip():
        try:
            parsed_slot_uuid = uuid.UUID(slot_id.strip())
        except ValueError as exc:
            raise ValueError("slot_id không hợp lệ.") from exc

    if parsed_slot_uuid is not None:
        slot = db.query(TimeSlot).filter(TimeSlot.slot_id == parsed_slot_uuid).first()
        if slot:
            return slot, None, None
        if not (start_time and start_time.strip() and end_time and end_time.strip()):
            raise ValueError("Không tìm thấy khung giờ phù hợp.")

    has_start = bool(start_time and start_time.strip())
    has_end = bool(end_time and end_time.strip())
    if has_start != has_end:
        raise ValueError("Vui lòng cung cấp đầy đủ giờ bắt đầu và giờ kết thúc.")

    if has_start and has_end:
        st, et = validate_time_range(
            start_time,  # type: ignore[arg-type]
            end_time,  # type: ignore[arg-type]
            enforce_working_hours=enforce_working_hours,
        )
        matched_slot = (
            db.query(TimeSlot)
            .filter(TimeSlot.start_time == st, TimeSlot.end_time == et)
            .first()
        )
        if matched_slot:
            return matched_slot, None, None
        return None, st, et

    if fallback_to_first_slot:
        first_slot = db.query(TimeSlot).order_by(TimeSlot.order_index.asc()).first()
        if first_slot:
            return first_slot, None, None

    raise ValueError("Không tìm thấy khung giờ phù hợp.")


# ===========================================================================
# ClassSchedule Services (Option A - Flat Response)
# ===========================================================================
def get_schedules_by_class(
    db: Session, class_id: uuid.UUID, day_of_week: int | None = None
) -> list[ClassSchedule]:
    query = (
        db.query(ClassSchedule)
        .options(
            joinedload(ClassSchedule.time_slot),
            joinedload(ClassSchedule.subject),
            joinedload(ClassSchedule.teacher),
        )
        .filter(ClassSchedule.class_id == class_id, ClassSchedule.is_active.is_(True))
    )

    if day_of_week is not None:
        query = query.filter(ClassSchedule.day_of_week == day_of_week)

    # Outer join keeps custom-time entries (slot_id IS NULL); final chronological sort handles custom hours.
    query = query.outerjoin(
        TimeSlot, ClassSchedule.slot_id == TimeSlot.slot_id
    ).order_by(ClassSchedule.day_of_week.asc(), TimeSlot.order_index.asc())

    return sorted(query.all(), key=schedule_sort_key)


def get_schedules_by_teacher(
    db: Session, teacher_id: uuid.UUID, day_of_week: int | None = None
) -> list[ClassSchedule]:
    query = (
        db.query(ClassSchedule)
        .options(
            joinedload(ClassSchedule.time_slot),
            joinedload(ClassSchedule.subject),
            joinedload(ClassSchedule.class_),
        )
        .filter(ClassSchedule.teacher_id == teacher_id, ClassSchedule.is_active.is_(True))
    )

    if day_of_week is not None:
        query = query.filter(ClassSchedule.day_of_week == day_of_week)

    query = query.outerjoin(
        TimeSlot, ClassSchedule.slot_id == TimeSlot.slot_id
    ).order_by(ClassSchedule.day_of_week.asc(), TimeSlot.order_index.asc())

    return sorted(query.all(), key=schedule_sort_key)


def _build_time_match_filters(
    slot_id: uuid.UUID | None,
    custom_start_time: str | None = None,
    custom_end_time: str | None = None,
) -> list:
    if slot_id is not None:
        return [ClassSchedule.slot_id == slot_id]
    return [
        ClassSchedule.slot_id.is_(None),
        ClassSchedule.custom_start_time == custom_start_time,
        ClassSchedule.custom_end_time == custom_end_time,
    ]


def check_schedule_conflict(
    db: Session,
    class_id: uuid.UUID,
    slot_id: uuid.UUID | None,
    day_of_week: int,
    teacher_id: uuid.UUID | None = None,
    exclude_schedule_id: uuid.UUID | None = None,
    custom_start_time: str | None = None,
    custom_end_time: str | None = None,
) -> str | None:
    """
    Kiểm tra xung đột thời khóa biểu:
    1. Trùng khung giờ trong cùng 1 lớp vào 1 ngày.
    2. Trùng khung giờ dạy của giáo viên vào 1 ngày.
    Trả về chuỗi báo lỗi chi tiết nếu có xung đột, ngược lại trả về None.
    """
    time_filters = _build_time_match_filters(
        slot_id, custom_start_time, custom_end_time
    )

    # 1. Kiểm tra trùng tiết của lớp
    class_query = db.query(ClassSchedule).filter(
        ClassSchedule.class_id == class_id,
        *time_filters,
        ClassSchedule.day_of_week == day_of_week,
        ClassSchedule.is_active.is_(True),
    )
    if exclude_schedule_id:
        class_query = class_query.filter(
            ClassSchedule.schedule_id != exclude_schedule_id
        )

    if class_query.first():
        return f"Lớp học này đã có tiết học khác vào Thứ {day_of_week} trong khung giờ này."

    # 2. Kiểm tra trùng tiết dạy của giáo viên (nếu có teacher_id)
    if teacher_id:
        teacher_query = db.query(ClassSchedule).filter(
            ClassSchedule.teacher_id == teacher_id,
            *time_filters,
            ClassSchedule.day_of_week == day_of_week,
            ClassSchedule.is_active.is_(True),
        )
        if exclude_schedule_id:
            teacher_query = teacher_query.filter(
                ClassSchedule.schedule_id != exclude_schedule_id
            )

        if teacher_query.first():
            return f"Giáo viên đã có lịch dạy ở lớp khác vào Thứ {day_of_week} trong khung giờ này."

    return None


def create_class_schedule(db: Session, data: ClassScheduleCreate) -> ClassSchedule:
    slot, custom_start, custom_end = resolve_schedule_time_selection(
        db,
        slot_id=data.slot_id,
        start_time=data.custom_start_time,
        end_time=data.custom_end_time,
        enforce_working_hours=True,
    )
    resolved_slot_id = slot.slot_id if slot else None

    # Check conflict
    conflict_msg = check_schedule_conflict(
        db,
        class_id=data.class_id,
        slot_id=resolved_slot_id,
        day_of_week=data.day_of_week,
        teacher_id=data.teacher_id,
        custom_start_time=custom_start,
        custom_end_time=custom_end,
    )
    if conflict_msg:
        raise ValueError(conflict_msg)

    schedule = ClassSchedule(
        schedule_id=uuid.uuid4(),
        class_id=data.class_id,
        subject_id=data.subject_id,
        slot_id=resolved_slot_id,
        custom_start_time=custom_start,
        custom_end_time=custom_end,
        teacher_id=data.teacher_id,
        day_of_week=data.day_of_week,
        activity_name=data.activity_name,
        content=data.content,
        room_name=data.room_name,
        is_active=data.is_active,
    )
    db.add(schedule)
    db.commit()

    # Re-query with eager relationships
    return (
        db.query(ClassSchedule)
        .options(
            joinedload(ClassSchedule.time_slot),
            joinedload(ClassSchedule.subject),
            joinedload(ClassSchedule.teacher),
        )
        .filter(ClassSchedule.schedule_id == schedule.schedule_id)
        .first()
    )


def update_class_schedule(
    db: Session, schedule_id: uuid.UUID, data: ClassScheduleUpdate
) -> ClassSchedule | None:
    schedule = (
        db.query(ClassSchedule).filter(ClassSchedule.schedule_id == schedule_id).first()
    )
    if not schedule:
        return None

    update_dict = data.model_dump(exclude_unset=True)

    # Guard older mobile clients that send synthetic time_slot.slot_id == schedule_id on custom entries
    if (
        "slot_id" in update_dict
        and update_dict["slot_id"] == schedule.schedule_id
        and schedule.slot_id is None
        and "custom_start_time" not in update_dict
        and "custom_end_time" not in update_dict
    ):
        update_dict.pop("slot_id")

    time_fields_present = any(
        k in update_dict
        for k in ("slot_id", "custom_start_time", "custom_end_time")
    )
    if time_fields_present:
        req_slot_id = update_dict.get("slot_id")
        req_start = update_dict.get("custom_start_time")
        req_end = update_dict.get("custom_end_time")
        if req_slot_id is None and (req_start is not None or req_end is not None):
            req_start = req_start if req_start is not None else schedule.custom_start_time
            req_end = req_end if req_end is not None else schedule.custom_end_time

        slot, custom_start, custom_end = resolve_schedule_time_selection(
            db,
            slot_id=req_slot_id,
            start_time=req_start,
            end_time=req_end,
            enforce_working_hours=True,
        )
        update_dict["slot_id"] = slot.slot_id if slot else None
        update_dict["custom_start_time"] = custom_start
        update_dict["custom_end_time"] = custom_end

    new_class_id = schedule.class_id
    new_slot_id = update_dict.get("slot_id", schedule.slot_id)
    new_custom_start = update_dict.get("custom_start_time", schedule.custom_start_time)
    new_custom_end = update_dict.get("custom_end_time", schedule.custom_end_time)
    new_day = update_dict.get("day_of_week", schedule.day_of_week)
    new_teacher_id = update_dict.get("teacher_id", schedule.teacher_id)

    # Check conflict if time, day, or teacher changes
    if time_fields_present or any(k in update_dict for k in ["day_of_week", "teacher_id"]):
        conflict_msg = check_schedule_conflict(
            db,
            class_id=new_class_id,
            slot_id=new_slot_id,
            day_of_week=new_day,
            teacher_id=new_teacher_id,
            exclude_schedule_id=schedule_id,
            custom_start_time=new_custom_start,
            custom_end_time=new_custom_end,
        )
        if conflict_msg:
            raise ValueError(conflict_msg)

    for field, value in update_dict.items():
        setattr(schedule, field, value)

    db.commit()

    return (
        db.query(ClassSchedule)
        .options(
            joinedload(ClassSchedule.time_slot),
            joinedload(ClassSchedule.subject),
            joinedload(ClassSchedule.teacher),
        )
        .filter(ClassSchedule.schedule_id == schedule_id)
        .first()
    )


def bulk_upsert_class_schedule(
    db: Session, class_id: uuid.UUID, items: list[ClassScheduleBulkCreateItem]
) -> list[ClassSchedule]:
    """
    Xóa toàn bộ thời khóa biểu cũ của lớp và thay thế bằng danh sách mới trong 1 transaction.
    """
    resolved_items = []
    for item in items:
        slot, custom_start, custom_end = resolve_schedule_time_selection(
            db,
            slot_id=item.slot_id,
            start_time=item.custom_start_time,
            end_time=item.custom_end_time,
            enforce_working_hours=True,
        )
        resolved_items.append((item, slot.slot_id if slot else None, custom_start, custom_end))

    # Xóa lịch cũ của lớp này
    db.query(ClassSchedule).filter(ClassSchedule.class_id == class_id).delete()

    for item, resolved_slot_id, custom_start, custom_end in resolved_items:
        sched = ClassSchedule(
            class_id=class_id,
            subject_id=item.subject_id,
            slot_id=resolved_slot_id,
            custom_start_time=custom_start,
            custom_end_time=custom_end,
            teacher_id=item.teacher_id,
            day_of_week=item.day_of_week,
            activity_name=item.activity_name,
            content=item.content,
            room_name=item.room_name,
            is_active=True,
        )
        db.add(sched)

    db.commit()

    return get_schedules_by_class(db, class_id)


def delete_class_schedule(db: Session, schedule_id: uuid.UUID) -> bool:
    schedule = (
        db.query(ClassSchedule).filter(ClassSchedule.schedule_id == schedule_id).first()
    )
    if not schedule:
        return False
    db.delete(schedule)
    db.commit()
    return True
