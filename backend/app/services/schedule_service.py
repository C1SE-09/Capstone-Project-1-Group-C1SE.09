"""
app/services/schedule_service.py
================================
Nghiệp vụ (Service Layer) cho quản lý Thời khóa biểu (TimeSlot, Subject, ClassSchedule).
"""

from __future__ import annotations

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

    # Order by day_of_week, then order_index of time_slot
    query = query.join(TimeSlot, ClassSchedule.slot_id == TimeSlot.slot_id).order_by(
        ClassSchedule.day_of_week.asc(), TimeSlot.order_index.asc()
    )

    return query.all()


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

    query = query.join(TimeSlot, ClassSchedule.slot_id == TimeSlot.slot_id).order_by(
        ClassSchedule.day_of_week.asc(), TimeSlot.order_index.asc()
    )

    return query.all()


def check_schedule_conflict(
    db: Session,
    class_id: uuid.UUID,
    slot_id: uuid.UUID,
    day_of_week: int,
    teacher_id: uuid.UUID | None = None,
    exclude_schedule_id: uuid.UUID | None = None,
) -> str | None:
    """
    Kiểm tra xung đột thời khóa biểu:
    1. Trùng khung giờ trong cùng 1 lớp vào 1 ngày.
    2. Trùng khung giờ dạy của giáo viên vào 1 ngày.
    Trả về chuỗi báo lỗi chi tiết nếu có xung đột, ngược lại trả về None.
    """
    # 1. Kiểm tra trùng tiết của lớp
    class_query = db.query(ClassSchedule).filter(
        ClassSchedule.class_id == class_id,
        ClassSchedule.slot_id == slot_id,
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
            ClassSchedule.slot_id == slot_id,
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
    # Check conflict
    conflict_msg = check_schedule_conflict(
        db,
        class_id=data.class_id,
        slot_id=data.slot_id,
        day_of_week=data.day_of_week,
        teacher_id=data.teacher_id,
    )
    if conflict_msg:
        raise ValueError(conflict_msg)

    schedule = ClassSchedule(
        schedule_id=uuid.uuid4(),
        class_id=data.class_id,
        subject_id=data.subject_id,
        slot_id=data.slot_id,
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

    new_class_id = schedule.class_id
    new_slot_id = update_dict.get("slot_id", schedule.slot_id)
    new_day = update_dict.get("day_of_week", schedule.day_of_week)
    new_teacher_id = update_dict.get("teacher_id", schedule.teacher_id)

    # Check conflict if time or teacher changes
    if any(k in update_dict for k in ["slot_id", "day_of_week", "teacher_id"]):
        conflict_msg = check_schedule_conflict(
            db,
            class_id=new_class_id,
            slot_id=new_slot_id,
            day_of_week=new_day,
            teacher_id=new_teacher_id,
            exclude_schedule_id=schedule_id,
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
    # Xóa lịch cũ của lớp này
    db.query(ClassSchedule).filter(ClassSchedule.class_id == class_id).delete()

    created_schedules = []
    for item in items:
        sched = ClassSchedule(
            class_id=class_id,
            subject_id=item.subject_id,
            slot_id=item.slot_id,
            teacher_id=item.teacher_id,
            day_of_week=item.day_of_week,
            activity_name=item.activity_name,
            content=item.content,
            room_name=item.room_name,
            is_active=True,
        )
        db.add(sched)
        created_schedules.append(sched)

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
