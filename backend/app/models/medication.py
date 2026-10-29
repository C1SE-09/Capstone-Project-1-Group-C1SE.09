"""
backend/app/models/medication.py
================================
SQLAlchemy 2.0 ORM Models: MedicationRequest, MedicationLog
-----------------------------------------------------------
Mô hình quản lý dặn thuốc và lịch sử cho trẻ uống thuốc tại lớp:
- MedicationRequest: Lời dặn thuốc cho học sinh (tên thuốc, liều lượng, cách dùng, các buổi trong ngày).
- MedicationLog: Lịch sử xác nhận đã cho uống thuốc của giáo viên theo từng ngày và buổi.
"""

from __future__ import annotations

import enum
import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy import (
    Enum as SAEnum,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship, synonym

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.child import Child, Parent
    from app.models.user import Class_, Teacher, User


class MedicationRequestStatus(str, enum.Enum):
    """Trạng thái của đơn dặn thuốc."""

    ACTIVE = "active"        # Đang có hiệu lực
    COMPLETED = "completed"  # Đã hoàn thành đợt uống
    CANCELLED = "cancelled"  # Phụ huynh huỷ
    PENDING = "pending"      # Tương thích với AC
    GIVEN = "given"          # Tương thích với AC


# Compatibility alias
MedicationStatus = MedicationRequestStatus


class MedicationSession(str, enum.Enum):
    """Mốc thời gian cho trẻ uống thuốc trong ngày."""

    MORNING = "morning"      # Buổi sáng
    NOON = "noon"            # Buổi trưa
    AFTERNOON = "afternoon"  # Buổi chiều


class MedicineCategory(str, enum.Enum):
    """Danh mục thuốc phổ biến (US 3.1)."""

    PRESCRIPTION = "prescription"      # Thuốc theo đơn bác sĩ / Đã chia liều
    FEVER_REDUCER = "fever_reducer"    # Thuốc hạ sốt
    COUGH_THROAT = "cough_throat"      # Thuốc ho / đau họng / siro ho
    LOZENGE = "lozenge"                # Viên ngậm
    DIGESTIVE = "digestive"            # Men tiêu hóa / vi sinh
    EYE_NOSE_DROPS = "eye_nose_drops"  # Thuốc nhỏ mắt / mũi
    OTHER = "other"                    # Khác


class MedicationRequest(Base, TimestampMixin):
    """Bảng đơn / lời dặn thuốc cho bé."""

    __tablename__ = "medication_request"

    __table_args__ = (
        Index("ix_medication_request_child_id", "child_id"),
        Index("ix_medication_request_class_id", "class_id"),
        Index("ix_medication_request_status", "status"),
        Index("ix_medication_request_dates", "start_date", "end_date"),
        {"comment": "Đơn dặn thuốc cho học sinh tại lớp mầm non"},
    )

    request_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Mã định danh đơn dặn thuốc (UUID v4)",
    )

    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("child.child_id", ondelete="CASCADE", name="fk_medication_request_child_id"),
        nullable=False,
        comment="Học sinh cần uống thuốc",
    )

    class_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="CASCADE", name="fk_medication_request_class_id"),
        nullable=False,
        comment="Lớp học của học sinh",
    )

    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("parent.parent_id", ondelete="SET NULL", name="fk_medication_request_parent_id"),
        nullable=True,
        comment="Phụ huynh gửi lời dặn (nếu có)",
    )

    medication_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        default="Thuốc theo đơn",
        comment="Tên thuốc (vd: Kháng sinh Cefixim, Siro ho Prospan)",
    )

    dosage: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Liều lượng (vd: 5ml, 1 gói, 1/2 viên)",
    )

    instructions: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Hướng dẫn uống chi tiết (vd: Uống sau ăn 15p, uống cùng nhiều nước ấm)",
    )

    sessions: Mapped[list[str]] = mapped_column(
        JSON,
        nullable=False,
        default=list,
        comment="Danh sách các buổi cần uống trong ngày: ['morning', 'noon', 'afternoon']",
    )

    start_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        default=date.today,
        comment="Ngày bắt đầu cho uống",
    )

    end_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        default=date.today,
        comment="Ngày kết thúc đợt thuốc",
    )

    status: Mapped[MedicationRequestStatus] = mapped_column(
        SAEnum(
            MedicationRequestStatus,
            name="medication_request_status",
            values_callable=lambda enum_cls: [e.value for e in enum_cls],
            create_type=False,
        ),
        nullable=False,
        default=MedicationRequestStatus.ACTIVE,
        server_default=MedicationRequestStatus.ACTIVE.value,
        comment="Trạng thái đơn dặn thuốc",
    )

    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Ghi chú thêm từ phụ huynh",
    )

    # --- Trường mở rộng cho US 3.1 ---
    batch_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
        comment="Mã đợt dặn thuốc gom nhiều cữ",
    )

    time_slot: Mapped[str | None] = mapped_column(
        String(10),
        nullable=True,
        comment="Khung giờ uống cụ thể (e.g. 08:30)",
    )

    request_date: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        comment="Ngày uống cữ thuốc",
    )

    medicine_category: Mapped[MedicineCategory | None] = mapped_column(
        SAEnum(
            MedicineCategory,
            name="medicine_category_enum",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        nullable=True,
        default=MedicineCategory.PRESCRIPTION,
    )

    prescription_image_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment="Ảnh đơn thuốc hoặc bao bì túi thuốc",
    )

    created_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="SET NULL"),
        nullable=True,
        comment="Tài khoản tạo đơn",
    )

    created_by_role: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="parent | teacher",
    )

    given_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Thời điểm thực tế cho uống",
    )

    given_by_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("teacher.teacher_id", ondelete="SET NULL"),
        nullable=True,
        comment="Giáo viên cho uống",
    )

    # Synonyms để hỗ trợ cả code đồng nghiệp và code US 3.1
    id = synonym("request_id")
    medicine_name = synonym("medication_name")

    # Relationships
    child: Mapped[Child] = relationship("Child", lazy="joined")
    class_: Mapped[Class_] = relationship("Class_", lazy="select")
    parent: Mapped[Parent | None] = relationship("Parent", lazy="joined")
    teacher: Mapped[Teacher | None] = relationship("Teacher", foreign_keys=[given_by_id])
    created_by_user: Mapped[User | None] = relationship("User", foreign_keys=[created_by_user_id])
    logs: Mapped[list[MedicationLog]] = relationship(
        "MedicationLog",
        back_populates="request",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<MedicationRequest id={self.request_id!s} child_id={self.child_id!s} med={self.medication_name!r}>"


class MedicationLog(Base, TimestampMixin):
    """Bảng lưu vết từng lần cho trẻ uống thuốc thực tế theo ngày & buổi."""

    __tablename__ = "medication_log"

    __table_args__ = (
        UniqueConstraint("request_id", "log_date", "session", name="uq_medication_log_request_date_session"),
        Index("ix_medication_log_date_session", "log_date", "session"),
        Index("ix_medication_log_given_by", "given_by_id"),
        {"comment": "Lịch sử thực tế giáo viên cho trẻ uống thuốc từng buổi"},
    )

    log_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Mã định danh lần cho uống (UUID v4)",
    )

    request_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("medication_request.request_id", ondelete="CASCADE", name="fk_medication_log_request_id"),
        nullable=False,
        comment="Đơn dặn thuốc tương ứng",
    )

    log_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Ngày cho uống thuốc",
    )

    session: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="Buổi cho uống: morning, noon, afternoon",
    )

    is_given: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Đã cho uống thuốc thành công hay chưa",
    )

    given_by_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("teacher.teacher_id", ondelete="SET NULL", name="fk_medication_log_given_by_id"),
        nullable=True,
        comment="Giáo viên trực tiếp cho bé uống",
    )

    given_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Thời điểm cô bấm xác nhận cho uống thuốc",
    )

    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Ghi chú phản ứng sau khi uống (vd: bé uống ngoan, nôn trớ...)",
    )

    # Relationships
    request: Mapped[MedicationRequest] = relationship("MedicationRequest", back_populates="logs")
    given_by: Mapped[Teacher | None] = relationship("Teacher", lazy="joined")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<MedicationLog id={self.log_id!s} request_id={self.request_id!s} session={self.session} is_given={self.is_given}>"
