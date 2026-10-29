"""
app/models/medication.py
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
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.child import Child, Parent
    from app.models.user import Class_, Teacher, User


class MedicationStatus(str, enum.Enum):
    """Trạng thái cữ uống thuốc."""

    PENDING = "pending"        # Đang chờ cô cho uống
    GIVEN = "given"            # Cô đã cho bé uống
    CANCELLED = "cancelled"    # Phụ huynh đã hủy


class MedicineCategory(str, enum.Enum):
    """Danh mục thuốc phổ biến."""

    PRESCRIPTION = "prescription"      # Thuốc theo đơn bác sĩ / Đã chia liều
    FEVER_REDUCER = "fever_reducer"    # Thuốc hạ sốt
    COUGH_THROAT = "cough_throat"      # Thuốc ho / đau họng / siro ho
    LOZENGE = "lozenge"                # Viên ngậm
    DIGESTIVE = "digestive"            # Men tiêu hóa / vi sinh
    EYE_NOSE_DROPS = "eye_nose_drops"  # Thuốc nhỏ mắt / mũi
    OTHER = "other"                    # Khác


class MedicationRequest(Base, TimestampMixin):
    """Bảng lưu thông tin đơn dặn thuốc theo từng cữ uống."""

    __tablename__ = "medication_requests"

    __table_args__ = (
        Index("ix_medication_requests_batch_id", "batch_id"),
        Index("ix_medication_requests_child_date", "child_id", "request_date"),
        Index("ix_medication_requests_class_date", "class_id", "request_date"),
        Index("ix_medication_requests_status", "status"),
        {"comment": "Đơn dặn thuốc và nhật ký cho trẻ uống thuốc"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Khóa chính cữ uống thuốc",
    )

    batch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        default=uuid.uuid4,
        comment="Mã đợt dặn thuốc (gom nhiều cữ/nhiều ngày lại chung đợt)",
    )

    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("child.child_id", ondelete="CASCADE"),
        nullable=False,
        comment="Học sinh nhận thuốc",
    )

    parent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("parent.parent_id", ondelete="CASCADE"),
        nullable=False,
        comment="Phụ huynh của học sinh (đối soát y tế bắt buộc)",
    )

    class_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="CASCADE"),
        nullable=False,
        comment="Lớp học của học sinh",
    )

    request_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Ngày cho bé uống thuốc",
    )

    time_slot: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        comment="Khung giờ uống thuốc (ví dụ: '08:30', '11:30')",
    )

    medicine_category: Mapped[MedicineCategory] = mapped_column(
        SAEnum(
            MedicineCategory,
            name="medicine_category_enum",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        nullable=False,
        default=MedicineCategory.PRESCRIPTION,
        comment="Phân loại thuốc / Danh mục gợi ý",
    )

    medicine_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Tên thuốc cụ thể (tùy chọn)",
    )

    dosage: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Liều lượng (ví dụ: '1 gói chia sẵn', '5ml', '1 viên')",
    )

    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Ghi chú dặn dò thêm (sau ăn no, pha nước ấm...)",
    )

    prescription_image_url: Mapped[str] = mapped_column(
        String(512),
        nullable=False,
        comment="Ảnh đơn thuốc hoặc bao bì túi thuốc (bắt buộc)",
    )

    status: Mapped[MedicationStatus] = mapped_column(
        SAEnum(
            MedicationStatus,
            name="medication_status_enum",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        nullable=False,
        default=MedicationStatus.PENDING,
        comment="Trạng thái cữ thuốc: pending | given | cancelled",
    )

    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        comment="Tài khoản thực tế đã bấm tạo đơn (Phụ huynh hoặc Giáo viên)",
    )

    created_by_role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="Role người tạo ('parent' hoặc 'teacher')",
    )

    given_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Thời điểm thực tế cô giáo cho bé uống",
    )

    given_by_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("teacher.teacher_id", ondelete="SET NULL"),
        nullable=True,
        comment="Giáo viên đã xác nhận cho uống thuốc",
    )

    # Relationships
    child: Mapped[Child] = relationship("Child", foreign_keys=[child_id])
    parent: Mapped[Parent] = relationship("Parent", foreign_keys=[parent_id])
    class_: Mapped[Class_] = relationship("Class_", foreign_keys=[class_id])
    teacher: Mapped[Teacher | None] = relationship("Teacher", foreign_keys=[given_by_id])
    created_by_user: Mapped[User] = relationship("User", foreign_keys=[created_by_user_id])
