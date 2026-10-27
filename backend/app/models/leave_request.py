"""
app/models/leave_request.py
===========================
SQLAlchemy ORM Model: LeaveRequest
----------------------------------
Lưu trữ thông tin đơn xin nghỉ học của học sinh do phụ huynh gửi,
giáo viên xem xét và duyệt/từ chối kèm lý do.
"""

from __future__ import annotations

import enum
import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Date,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
)
from sqlalchemy import (
    Enum as SAEnum,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.child import Child, Parent
    from app.models.user import Class_, Teacher


class LeaveRequestStatus(str, enum.Enum):
    """Trạng thái của đơn xin nghỉ."""
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class LeaveRequest(Base, TimestampMixin):
    """Bảng đơn xin nghỉ học."""

    __tablename__ = "leave_request"

    request_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("child.child_id", ondelete="CASCADE"),
        nullable=False,
    )

    parent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("parent.parent_id", ondelete="CASCADE"),
        nullable=False,
    )

    class_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="CASCADE"),
        nullable=False,
    )

    from_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Ngày bắt đầu nghỉ",
    )

    to_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Ngày kết thúc nghỉ",
    )

    reason: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Lý do xin nghỉ của phụ huynh",
    )

    attachment_url: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
        comment="Đường dẫn ảnh đơn thuốc / giấy khám bệnh (nếu có)",
    )

    status: Mapped[LeaveRequestStatus] = mapped_column(
        SAEnum(
            LeaveRequestStatus,
            name="leave_request_status",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        nullable=False,
        default=LeaveRequestStatus.PENDING,
    )

    reject_reason: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Lý do từ chối (bắt buộc khi status = REJECTED)",
    )

    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("teacher.teacher_id", ondelete="SET NULL"),
        nullable=True,
        comment="Giáo viên xử lý đơn",
    )

    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Thời điểm duyệt hoặc từ chối",
    )

    # Relationships
    child: Mapped[Child] = relationship("Child", foreign_keys=[child_id], lazy="joined")
    parent: Mapped[Parent] = relationship("Parent", foreign_keys=[parent_id], lazy="joined")
    class_: Mapped[Class_] = relationship("Class_", foreign_keys=[class_id], lazy="select")
    reviewer: Mapped[Teacher | None] = relationship("Teacher", foreign_keys=[reviewed_by], lazy="joined")

    __table_args__ = (
        Index("ix_leave_request_class_status", "class_id", "status"),
        Index("ix_leave_request_child_dates", "child_id", "from_date", "to_date"),
    )
