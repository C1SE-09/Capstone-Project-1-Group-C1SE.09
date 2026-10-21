"""
app/models/attendance.py
========================
SQLAlchemy 2.0 ORM Model: AttendanceRecord
------------------------------------------
Ghi nhận điểm danh hàng ngày của từng học sinh trong lớp.
Tuân thủ:
- Khóa chính UUID native PostgreSQL
- TimestampMixin (created_at, updated_at)
- UniqueConstraint(child_id, date): Mỗi trẻ chỉ có 1 trạng thái trong ngày
- Index(class_id, date): Tối ưu truy vấn bảng điểm danh theo lớp < 200ms
"""

from __future__ import annotations

import enum
import uuid
from datetime import date, time
from typing import TYPE_CHECKING

from sqlalchemy import (
    Date,
    ForeignKey,
    Index,
    String,
    Time,
    UniqueConstraint,
)
from sqlalchemy import (
    Enum as SAEnum,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.child import Child
    from app.models.user import Class_, Teacher

class AttendanceStatus(str, enum.Enum):
    """Trạng thái điểm danh của trẻ."""
    PRESENT = "present" #có mặt
    ABSENT = "absent" #vắng mặt
    LATE = "late" #đến muộn

class AttendanceRecord(Base, TimestampMixin):
    """Trạng thái điểm danh của trẻ."""

    __tablename__ = "attendance_record"

    record_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("child.child_id", ondelete="CASCADE"),
        nullable=False,
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="CASCADE"),
        nullable=False,
    )

    date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    status: Mapped[AttendanceStatus] = mapped_column(
        SAEnum(
            AttendanceStatus,
            name="attendance_status",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        nullable=False,
        default=AttendanceStatus.PRESENT,
    )

    check_in_time: Mapped[time | None] = mapped_column(
        Time,
        nullable=True,
        comment="Giờ vào lớp thực tế (dùng khi trẻ đi muộn)",
    )

    note: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Ghi chú nhanh của cô (vd: ba mẹ xin phép trước)",
    )

    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("teacher.teacher_id", ondelete="SET NULL"),
        nullable=True,
        comment="Giáo viên thực hiện điểm danh (Audit log an toàn)",
    )

    #relationship
    child: Mapped[Child] = relationship("Child", lazy="joined")
    class_: Mapped[Class_] = relationship("Class_")
    teacher: Mapped[Teacher] = relationship("Teacher")

    __table_args__ = (
        UniqueConstraint(
            "child_id",
            "date",
            name="uq_attendance_child_date",
        ),
        Index(
            "ix_attendance_class_date",
            "class_id",
            "date",
        ),
    )