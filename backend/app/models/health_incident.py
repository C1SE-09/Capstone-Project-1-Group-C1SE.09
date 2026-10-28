"""
backend/app/models/health_incident.py
=====================================
SQLAlchemy 2.0 ORM Model: HealthIncident
----------------------------------------
Quản lý các sự cố sức khỏe / tai nạn khẩn cấp tại lớp mầm non:
- Sốt cao (High fever)
- Tai nạn / Chấn thương (Severe injury)
- Dị ứng cấp tính (Acute allergy)
- Sự cố khác (Other)
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import (
    DateTime,
    Float,
    ForeignKey,
    Index,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.child import Child
    from app.models.user import Class_, Teacher


class HealthIncidentType(str, enum.Enum):
    """Phân loại sự cố sức khỏe khẩn cấp."""
    HIGH_FEVER = "high_fever"        # Sốt cao
    SEVERE_INJURY = "severe_injury"  # Tai nạn / Chấn thương
    ACUTE_ALLERGY = "acute_allergy"  # Dị ứng cấp tính
    OTHER = "other"                  # Sự cố khác


class HealthIncident(Base, TimestampMixin):
    """Bảng ghi nhận sự cố sức khỏe khẩn cấp tại lớp."""

    __tablename__ = "health_incident"

    __table_args__ = (
        Index("ix_health_incident_child_id", "child_id"),
        Index("ix_health_incident_class_id", "class_id"),
        Index("ix_health_incident_type", "incident_type"),
        Index("ix_health_incident_reported_at", "reported_at"),
        {"comment": "Sự cố sức khỏe và tai nạn khẩn cấp của học sinh tại lớp"},
    )

    incident_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Mã định danh sự cố (UUID v4)",
    )

    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("child.child_id", ondelete="CASCADE", name="fk_health_incident_child_id"),
        nullable=False,
        comment="Học sinh gặp sự cố",
    )

    class_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="CASCADE", name="fk_health_incident_class_id"),
        nullable=False,
        comment="Lớp học của học sinh",
    )

    reported_by_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("teacher.teacher_id", ondelete="SET NULL", name="fk_health_incident_reported_by_id"),
        nullable=True,
        comment="Giáo viên phát cảnh báo / ghi nhận",
    )

    incident_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default=HealthIncidentType.OTHER.value,
        server_default=HealthIncidentType.OTHER.value,
        comment="Loại sự cố: high_fever, severe_injury, acute_allergy, other",
    )

    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Mô tả sự cố (nếu cô không nhập, hệ thống tự động sinh theo loại)",
    )

    temperature: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Nhiệt độ cơ thể (°C) nếu là sốt cao",
    )

    action_taken: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Biện pháp sơ cứu đã thực hiện tại lớp (chườm ấm, băng bó, v.v.)",
    )

    reported_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        comment="Thời điểm phát cảnh báo",
    )

    # Relationships
    child: Mapped[Child] = relationship("Child", lazy="joined")
    class_: Mapped[Class_] = relationship("Class_", lazy="select")
    reported_by: Mapped[Teacher | None] = relationship("Teacher", lazy="joined")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<HealthIncident id={self.incident_id!s} child_id={self.child_id!s} type={self.incident_type}>"
