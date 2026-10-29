"""
app/models/schedule.py
======================
SQLAlchemy 2.0 ORM Models: TimeSlot, Subject, ClassSchedule
------------------------------------------------------------
Timetable / Schedule Management for ADARK Kindergarten System.
"""

from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.user import Class_, Teacher


class TimeSlot(Base, TimestampMixin):
    """Standard daily time slots defined for the system.

    Columns
    -------
    slot_id     : UUID PK
    name        : Display name (e.g., "7h00 - 7h30", "7h30 - 8h00")
    start_time  : Start time string (e.g., "07:00")
    end_time    : End time string (e.g., "07:30")
    order_index : Sort order in the daily timetable
    """

    __tablename__ = "time_slot"

    __table_args__ = (
        Index("ix_time_slot_order", "order_index"),
        {"comment": "Daily time slot definitions"},
    )

    slot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Slot display name, e.g. 7h00 - 7h30",
    )
    start_time: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        comment="Start time (HH:MM), e.g. 07:00",
    )
    end_time: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        comment="End time (HH:MM), e.g. 07:30",
    )
    order_index: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        comment="Display sort index",
    )

    # Relationships
    schedules: Mapped[list[ClassSchedule]] = relationship(
        "ClassSchedule", back_populates="time_slot", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<TimeSlot id={self.slot_id!s} name={self.name!r} start={self.start_time}>"
        )


class Subject(Base, TimestampMixin):
    """Subjects / Activity types offered in the timetable.

    Columns
    -------
    subject_id  : UUID PK
    name        : Subject/Activity name (e.g., "Tiếng Việt", "Tập thể dục", "Mỹ thuật")
    code        : Short code (e.g., "VIE", "ART")
    color_code  : Color code for UI rendering (e.g., "#4CAF50")
    description : Details or required items
    """

    __tablename__ = "subject"

    __table_args__ = (
        UniqueConstraint("name", name="uq_subject_name"),
        Index("ix_subject_name", "name"),
        {"comment": "Subjects and activity types for timetable"},
    )

    subject_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Subject name, e.g. Tiếng Việt, Mỹ thuật",
    )
    code: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="Short code, e.g. VIE, ART",
    )
    color_code: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        default="#4CAF50",
        comment="HEX color code for Flutter UI badges",
    )
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Detailed description or required items",
    )

    # Relationships
    schedules: Mapped[list[ClassSchedule]] = relationship(
        "ClassSchedule", back_populates="subject", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Subject id={self.subject_id!s} name={self.name!r}>"


class ClassSchedule(Base, TimestampMixin):
    """Timetable entry connecting a Class, Subject, TimeSlot, and Teacher.

    Columns
    -------
    schedule_id  : UUID PK
    class_id     : FK → class.class_id (CASCADE)
    subject_id   : FK → subject.subject_id (CASCADE)
    slot_id      : FK → time_slot.slot_id (CASCADE)
    teacher_id   : FK → teacher.teacher_id (SET NULL, optional)
    day_of_week  : Day of week (2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat)
    activity_name: Activity headline (e.g., "- Hoạt động có chủ đích")
    content      : Detailed activity description (e.g., "Tập thể dục buổi sáng", "Trẻ ăn cơm trưa")
    room_name    : Room/location name (e.g., "Lớp Mầm A", "Sân trường")
    is_active    : Active flag
    """

    __tablename__ = "class_schedule"

    __table_args__ = (
        Index("ix_class_schedule_class_id", "class_id"),
        Index("ix_class_schedule_day", "class_id", "day_of_week"),
        Index("ix_class_schedule_slot", "slot_id"),
        UniqueConstraint(
            "class_id", "day_of_week", "slot_id", name="uq_class_schedule_slot"
        ),
        {"comment": "Weekly class timetable entries"},
    )

    schedule_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "class.class_id", ondelete="CASCADE", name="fk_class_schedule_class_id"
        ),
        nullable=False,
        comment="Classroom entity",
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "subject.subject_id",
            ondelete="CASCADE",
            name="fk_class_schedule_subject_id",
        ),
        nullable=False,
        comment="Subject entity",
    )
    slot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "time_slot.slot_id", ondelete="CASCADE", name="fk_class_schedule_slot_id"
        ),
        nullable=False,
        comment="Time slot entity",
    )
    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "teacher.teacher_id",
            ondelete="SET NULL",
            name="fk_class_schedule_teacher_id",
        ),
        nullable=True,
        comment="Assigned teacher for this period (optional)",
    )
    day_of_week: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Day of week: 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday",
    )
    activity_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Activity headline / label",
    )
    content: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Detailed activity content description",
    )
    room_name: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Room or physical location name",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        comment="True if period is active",
    )

    # Relationships
    class_: Mapped[Class_] = relationship("Class_", lazy="joined")
    subject: Mapped[Subject] = relationship(
        "Subject", back_populates="schedules", lazy="joined"
    )
    time_slot: Mapped[TimeSlot] = relationship(
        "TimeSlot", back_populates="schedules", lazy="joined"
    )
    teacher: Mapped[Teacher | None] = relationship("Teacher", lazy="joined")

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<ClassSchedule id={self.schedule_id!s} class_id={self.class_id!s} "
            f"day={self.day_of_week} slot={self.slot_id!s}>"
        )


class Room(Base, TimestampMixin):
    """Rooms and physical locations in the school.

    Columns
    -------
    room_id   : UUID PK
    school_id : FK → school.school_id (CASCADE)
    class_id  : FK → class.class_id (SET NULL, optional, for dedicated classroom)
    name      : Display name (e.g. "Phòng học Mầm A", "Phòng Âm nhạc", "Sân cỏ")
    room_type : Type category (CLASSROOM, FUNCTIONAL, OUTDOOR, COMMON)
    capacity  : Max children capacity
    is_shared : If True, multiple classes can use this location at once without conflict
    is_active : Active flag
    """

    __tablename__ = "room"

    __table_args__ = (
        Index("ix_room_school_id", "school_id"),
        Index("ix_room_class_id", "class_id"),
        Index("ix_room_type", "room_type"),
        {"comment": "Physical rooms and locations within a school"},
    )

    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("school.school_id", ondelete="CASCADE", name="fk_room_school_id"),
        nullable=False,
        comment="Owning school",
    )
    class_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="SET NULL", name="fk_room_class_id"),
        nullable=True,
        comment="Dedicated classroom for this class (null if functional or shared space)",
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Display name of the room or location",
    )
    room_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="CLASSROOM",
        comment="Room type: CLASSROOM, FUNCTIONAL, OUTDOOR, COMMON",
    )
    capacity: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        default=30,
        comment="Capacity of children or occupants",
    )
    is_shared: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="True if multiple classes can occupy at the same time (e.g. Sân cỏ, Sân trường)",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        comment="Active flag",
    )

    # Relationships
    class_: Mapped[Class_ | None] = relationship("Class_", lazy="joined")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Room id={self.room_id!s} name={self.name!r} type={self.room_type!r} shared={self.is_shared}>"

