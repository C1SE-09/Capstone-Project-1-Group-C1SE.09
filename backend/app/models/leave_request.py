"""
app/models/leave_request.py
===========================
SQLAlchemy 2.0 ORM Model: LeaveRequest
Quản lý đơn xin nghỉ học và đi trễ của học sinh.
"""

from __future__ import annotations

import enum
import uuid
from datetime import date, datetime, time
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
    Time,
)
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship, synonym

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.child import Child, Parent
    from app.models.user import Class_, User


class LeaveType(str, enum.Enum):
    """Loại đơn xin nghỉ/đi trễ (AC1)."""
    SINGLE_DAY = "single_day"  # Nghỉ 1 ngày
    MULTI_DAY = "multi_day"    # Nghỉ nhiều ngày
    LATE = "late"              # Đi trễ


class LeaveStatus(str, enum.Enum):
    """Trạng thái duyệt đơn (AC4)."""
    PENDING = "pending"    # Chờ duyệt
    APPROVED = "approved"  # Đã duyệt
    REJECTED = "rejected"  # Bị từ chối
    CANCELLED = "cancelled"  # Phụ huynh huỷ đơn trước 07:30


# Compatibility alias for colleague code
LeaveRequestStatus = LeaveStatus


class LeaveRequest(Base, TimestampMixin):
    """Bảng lưu thông tin đơn xin nghỉ học và báo đi trễ."""

    __tablename__ = "leave_request"

    leave_id: Mapped[uuid.UUID] = mapped_column(
        "request_id",
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("child.child_id", ondelete="CASCADE"),
        nullable=False,
        comment="Học sinh xin nghỉ/đi trễ",
    )

    parent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("parent.parent_id", ondelete="CASCADE"),
        nullable=False,
        comment="Phụ huynh tạo đơn",
    )

    class_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="CASCADE"),
        nullable=False,
        comment="Lớp học của trẻ (hỗ trợ phân quyền giáo viên)",
    )

    type: Mapped[LeaveType] = mapped_column(
        SAEnum(
            LeaveType,
            name="leave_type",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        nullable=False,
        default=LeaveType.SINGLE_DAY,
    )

    from_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Ngày bắt đầu nghỉ hoặc ngày đi trễ",
    )

    to_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Ngày kết thúc nghỉ (với single_day/late thì trùng from_date)",
    )

    expected_arrival_time: Mapped[time | None] = mapped_column(
        Time,
        nullable=True,
        comment="Giờ dự kiến đến lớp (bắt buộc khi type = late)",
    )

    meal_warning_acknowledged: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false",
    )

    reason: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Lý do xin nghỉ hoặc đi trễ",
    )

    attachment_url: Mapped[str | None] = mapped_column(
        String(1000),
        nullable=True,
        comment="URL ảnh đính kèm (đơn thuốc, kết quả khám)",
    )

    contact_phone: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="Số điện thoại liên hệ khi cần",
    )

    submitted_after_cutoff: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        comment="Đánh dấu đơn nộp sau 07:30 sáng (AC2)",
    )

    status: Mapped[LeaveStatus] = mapped_column(
        SAEnum(
            LeaveStatus,
            name="leave_request_status",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        nullable=False,
        default=LeaveStatus.PENDING,
    )

    approved_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="SET NULL"),
        nullable=True,
        comment="Người duyệt đơn (giáo viên hoặc admin)",
    )

    reject_reason: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
        comment="Lý do từ chối nếu không duyệt",
    )

    action_at: Mapped[datetime | None] = mapped_column(
        "reviewed_at",
        DateTime(timezone=True),
        nullable=True,
        comment="Thời điểm duyệt hoặc từ chối",
    )

    # Backward compatibility synonyms
    request_id = synonym("leave_id")
    reviewed_by = synonym("approved_by")
    reviewed_at = synonym("action_at")

    # Relationships
    child: Mapped[Child] = relationship("Child", foreign_keys=[child_id], lazy="joined")
    parent: Mapped[Parent] = relationship("Parent", foreign_keys=[parent_id], lazy="select")
    class_: Mapped[Class_] = relationship("Class_", foreign_keys=[class_id], lazy="select")
    reviewer: Mapped[User | None] = relationship(
        "User", foreign_keys=[approved_by], lazy="joined",
    )

    __table_args__ = (
        Index("ix_leave_request_overlap", "child_id", "from_date", "to_date", "status"),
        Index("ix_leave_request_class_status", "class_id", "status"),
    )
