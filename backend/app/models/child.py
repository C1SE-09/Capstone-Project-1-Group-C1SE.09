"""
app/models/child.py
===================
SQLAlchemy 2.0 ORM Models: Child, Parent
-----------------------------------------
Entity hierarchy
~~~~~~~~~~~~~~~~
    Class_  1──*  Child
    Parent  1──*  Child   (one parent account shared by both father and mother)
    Child   1──*  DailyReport  (wired in TASK-1.2.3)

Design decisions
~~~~~~~~~~~~~~~~
* Follows the same SQLAlchemy 2.0 Mapped / mapped_column style as user.py.
* All PKs use ``uuid.UUID`` stored as native PostgreSQL ``UUID`` column.
* ``TimestampMixin`` injects ``created_at`` / ``updated_at`` from ``base.py``.
* ``medical_allergies`` is stored as free-text ``Text`` column so teachers can
  enter unstructured notes (e.g. "dị ứng tôm, lạc") without a rigid schema.
  AI extraction (Gemini) can parse these later if needed.
* Parent → Child is one-to-many (1-n): one Parent account (shared by both
  father and mother of a household) owns multiple children.
  This keeps auth simple – one Firebase UID per family.
* ``back_populates`` wires bidirectional relationships without circular imports:
  - Class_.children  → back_populates Child.class_  (Class_ lives in user.py)

TASK: TASK-1.2.2 – Child & Parent Models
"""

from __future__ import annotations

import enum
import uuid
from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    Date,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy import (
    Enum as SAEnum,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

# ---------------------------------------------------------------------------
# Forward-reference imports (avoid circular imports)
# ---------------------------------------------------------------------------
if TYPE_CHECKING:
    from app.models.report import (
        DailyReport,
        VoiceRecord,
    )
    from app.models.user import Class_


# ===========================================================================
# Enums
# ===========================================================================


class ChildStatus(str, enum.Enum):
    """Enrollment status of a Child record."""

    ENROLLED = "enrolled"
    WITHDRAWN = "withdrawn"
    GRADUATED = "graduated"


class ParentStatus(str, enum.Enum):
    """Account status of a Parent."""

    ACTIVE = "active"
    INACTIVE = "inactive"


# ===========================================================================
# Child
# ===========================================================================


class Child(Base, TimestampMixin):
    """A child / pupil enrolled in a Class_.

    Columns
    -------
    child_id          : UUID PK (auto-generated)
    parent_id         : FK → parent.parent_id  (SET NULL when parent is deleted)
    class_id          : FK → class.class_id    (SET NULL when class is deleted)
    full_name         : Full legal name (max 150 chars)
    nickname          : Preferred name used in daily reports (optional, max 50)
    date_of_birth     : Date of birth for age verification (optional)
    gender            : 'male' | 'female' | 'other' (optional)
    avatar_url        : Profile photo URL (optional)
    medical_allergies : Free-text allergy / medical notes (optional)
    status            : ChildStatus enum – defaults to ENROLLED

    Relationships
    -------------
    parent  : Parent          – owning parent account (nullable after deletion)
    class_  : Class_          – enrolled classroom (nullable after class deletion)
    """

    __tablename__ = "child"

    __table_args__ = (
        Index("ix_child_parent_id", "parent_id"),
        Index("ix_child_class_id", "class_id"),
        Index("ix_child_status", "status"),
        Index("ix_child_full_name", "full_name"),
        {"comment": "Children / pupils enrolled in kindergarten classes"},
    )

    # --- Primary key ---
    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign keys ---
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("parent.parent_id", ondelete="SET NULL", name="fk_child_parent_id"),
        nullable=True,
        comment="Owning parent account – NULL if parent account has been deleted",
    )
    class_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="SET NULL", name="fk_child_class_id"),
        nullable=True,
        comment="Enrolled class – NULL if class has been deleted",
    )

    # --- Personal info ---
    full_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        comment="Full legal name of the child",
    )
    nickname: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="Preferred nickname used in teacher voice reports and parent notifications",
    )
    date_of_birth: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        comment="Date of birth for age-group validation",
    )
    gender: Mapped[str | None] = mapped_column(
        String(10),
        nullable=True,
        comment="Gender: male | female | other",
    )
    avatar_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment="Profile photo URL in object storage",
    )

    # --- Health ---
    medical_allergies: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment=(
            "Free-text medical notes and allergy information, "
            "e.g. 'dị ứng tôm, không ăn được lạc'. "
            "Displayed in teacher app and included in daily report context."
        ),
    )

    # --- Status ---
    status: Mapped[ChildStatus] = mapped_column(
        SAEnum(ChildStatus, name="child_status_enum", create_type=True),
        nullable=False,
        default=ChildStatus.ENROLLED,
        server_default=ChildStatus.ENROLLED.value,
        comment="Enrollment lifecycle status",
    )

    # --- Relationships ---
    parent: Mapped[Parent | None] = relationship(
        "Parent",
        back_populates="children",
        lazy="joined",
    )
    class_: Mapped[Class_ | None] = relationship(
        "Class_",
        back_populates="children",
        lazy="joined",
    )
    voice_records: Mapped[list[VoiceRecord]] = relationship(
        "VoiceRecord",
        back_populates="child",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="VoiceRecord.recorded_at",
    )
    daily_reports: Mapped[list[DailyReport]] = relationship(
        "DailyReport",
        back_populates="child",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="DailyReport.report_date",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<Child id={self.child_id!s} name={self.full_name!r} "
            f"nickname={self.nickname!r} parent_id={self.parent_id!s}>"
        )


# ===========================================================================
# Parent
# ===========================================================================


class Parent(Base, TimestampMixin):
    """A parent / guardian account shared by a household (father + mother).

    One Parent account represents the family unit and can be linked to
    multiple children (siblings). Both parents share the same Firebase UID
    so they receive the same daily report notifications.

    Columns
    -------
    parent_id    : UUID PK (auto-generated)
    firebase_uid : Firebase Auth UID (unique, optional – linked after first login)
    full_name    : Primary contact's full name (max 150 chars)
    phone        : Primary contact phone number (unique, max 20 chars)
    email        : Contact email (optional, unique if provided, max 255 chars)
    avatar_url   : Profile photo URL (optional)
    status       : ParentStatus enum – defaults to ACTIVE
    is_verified  : True after school admin links the parent to a child

    Relationships
    -------------
    children : List[Child] – children belonging to this parent account (1-n)
    """

    __tablename__ = "parent"

    __table_args__ = (
        UniqueConstraint("phone", name="uq_parent_phone"),
        UniqueConstraint("email", name="uq_parent_email"),
        UniqueConstraint("firebase_uid", name="uq_parent_firebase_uid"),
        Index("ix_parent_phone", "phone"),
        Index("ix_parent_email", "email"),
        Index("ix_parent_status", "status"),
        {"comment": "Parent / guardian accounts registered in ADARK (one account per family)"},
    )

    # --- Primary key ---
    parent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Auth ---
    firebase_uid: Mapped[str | None] = mapped_column(
        String(128),
        nullable=True,
        comment="Firebase Authentication UID (linked after first login)",
    )

    # --- Personal info ---
    full_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        comment="Full display name of the primary contact (father or mother)",
    )
    phone: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="Primary mobile phone number – used for login and notifications",
    )
    email: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Optional contact email address",
    )
    avatar_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment="Profile photo URL in object storage",
    )

    # --- Status ---
    status: Mapped[ParentStatus] = mapped_column(
        SAEnum(ParentStatus, name="parent_status_enum", create_type=True),
        nullable=False,
        default=ParentStatus.ACTIVE,
        server_default=ParentStatus.ACTIVE.value,
        comment="Account lifecycle status",
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="True after school admin links this parent to at least one child",
    )

    # --- Relationships ---
    children: Mapped[list[Child]] = relationship(
        "Child",
        back_populates="parent",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="Child.full_name",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<Parent id={self.parent_id!s} name={self.full_name!r} "
            f"phone={self.phone!r}>"
        )
