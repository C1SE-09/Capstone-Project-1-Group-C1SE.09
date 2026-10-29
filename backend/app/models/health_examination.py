"""
app/models/health_examination.py
================================
SQLAlchemy 2.0 ORM Model: HealthExamination
-------------------------------------------
Ghi nhận số liệu sức khoẻ định kỳ của học sinh vào sổ sức khoẻ (chiều cao, cân nặng, BMI, phân loại thể trạng).
"""

from __future__ import annotations

import enum
import uuid
from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import (
    Date,
    Float,
    ForeignKey,
    Index,
    Text,
)
from sqlalchemy import (
    Enum as SAEnum,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.child import Child
    from app.models.user import User


class HealthCategory(str, enum.Enum):
    """Phân loại thể trạng của trẻ theo chỉ số BMI."""
    NORMAL = "NORMAL"
    UNDERWEIGHT = "UNDERWEIGHT"
    OVERWEIGHT = "OVERWEIGHT"


class HealthExamination(Base, TimestampMixin):
    """Số liệu sức khoẻ định kỳ của học sinh ghi trong sổ sức khoẻ."""

    __tablename__ = "health_examinations"

    examination_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("child.child_id", ondelete="CASCADE"),
        nullable=False,
        comment="Học sinh có số liệu ghi nhận",
    )

    examination_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        default=date.today,
        comment="Ngày ghi nhận số liệu",
    )

    height: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Chiều cao (cm) — có thể để trống nếu chỉ ghi kết luận chung",
    )

    weight: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Cân nặng (kg) — có thể để trống nếu chỉ ghi kết luận chung",
    )

    bmi: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Chỉ số khối cơ thể BMI (kg/m^2)",
    )

    health_category: Mapped[HealthCategory | None] = mapped_column(
        SAEnum(
            HealthCategory,
            name="health_category_enum",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        nullable=True,
        comment="Phân loại thể trạng (NORMAL / UNDERWEIGHT / OVERWEIGHT) — chỉ có khi đủ cao + nặng",
    )

    general_conclusion: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Kết luận chung của đợt ghi nhận",
    )

    created_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="SET NULL"),
        nullable=True,
        comment="Tài khoản thực hiện ghi nhận",
    )

    # Relationships
    child: Mapped[Child] = relationship(
        "Child",
        back_populates="health_examinations",
    )
    created_by_user: Mapped[User | None] = relationship(
        "User",
    )

    __table_args__ = (
        Index("ix_health_examinations_child_date", "child_id", "examination_date"),
    )
