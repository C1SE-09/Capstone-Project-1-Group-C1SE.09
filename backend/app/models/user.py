"""
app/models/user.py
==================
SQLAlchemy 2.0 ORM Models: School, Class_, Teacher
----------------------------------------------------
Entity hierarchy
~~~~~~~~~~~~~~~~
    School  1──* Class_  1──* Teacher   (Teacher belongs to one Class_ & one School)
    School  1──* Teacher               (direct FK for fast school-level queries)
    Class_  1──* Child                 (children enrolled in the class – TASK-1.2.2)

Design decisions
~~~~~~~~~~~~~~~~
* Uses SQLAlchemy 2.0 **Mapped / mapped_column** annotation style (fully type-safe).
* All PKs use ``uuid.UUID`` stored as native PostgreSQL ``UUID`` column.
* ``TimestampMixin`` injects ``created_at`` / ``updated_at`` from ``base.py``.
* ``__table_args__`` carries database-level constraints and indexes.
* Enum columns use Python ``enum.Enum`` + SQLAlchemy ``Enum`` type so values
  are validated both in Python and at the database layer.
* ``back_populates`` wires up bidirectional relationships without circular imports
  because Child / Parent models live in a separate file (models/child.py –
  implemented in TASK-1.2.2).

TASK: TASK-1.2.1 – School, Class & Teacher Models
"""

from __future__ import annotations

import enum
import uuid
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
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
    # Imported only for type checkers; not executed at runtime.
    from app.models.child import Child, Parent
    from app.models.report import (
        ClassBroadcastReport,
        DailyReport,
        VoiceRecord,
    )


# ===========================================================================
# Enums
# ===========================================================================


class SchoolStatus(str, enum.Enum):
    """Lifecycle status of a School record."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"


class TeacherStatus(str, enum.Enum):
    """Employment status of a Teacher."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    ON_LEAVE = "on_leave"


class UserRole(str, enum.Enum):
    """System access role for a User."""

    TEACHER = "teacher"
    PARENT = "parent"
    ADMIN = "admin"


class UserStatus(str, enum.Enum):
    """Account status of a User."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"


# ===========================================================================
# User
# ===========================================================================


class User(Base, TimestampMixin):
    """System authentication user account.

    Columns
    -------
    user_id       : UUID PK
    username      : Unique login username (max 50 chars)
    password_hash : Hashed password (max 255 chars)
    role          : UserRole enum ('teacher' | 'parent' | 'admin')
    teacher_id    : FK → teacher.teacher_id (CASCADE)
    parent_id     : FK → parent.parent_id (CASCADE)
    status        : UserStatus enum – defaults to ACTIVE
    is_verified   : Account verification status – defaults to True
    """

    __tablename__ = "users"

    __table_args__ = (
        UniqueConstraint("username", name="uq_users_username"),
        Index("ix_users_username", "username"),
        Index("ix_users_role", "role"),
        Index("ix_users_teacher_id", "teacher_id"),
        Index("ix_users_parent_id", "parent_id"),
        {"comment": "User accounts for authentication in ADARK"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )
    username: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Login username, e.g. teacher_mai or parent_tuan",
    )
    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Bcrypt password hash",
    )
    role: Mapped[UserRole] = mapped_column(
        SAEnum(UserRole, name="user_role_enum", values_callable=lambda enum_cls: [e.value for e in enum_cls], create_type=True),
        nullable=False,
        comment="Account role – teacher | parent | admin",
    )
    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "teacher.teacher_id", ondelete="CASCADE", name="fk_users_teacher_id"
        ),
        nullable=True,
        comment="Linked teacher entity (NULL if not a teacher)",
    )
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "parent.parent_id", ondelete="CASCADE", name="fk_users_parent_id"
        ),
        nullable=True,
        comment="Linked parent entity (NULL if not a parent)",
    )
    status: Mapped[UserStatus] = mapped_column(
        SAEnum(UserStatus, name="user_status_enum", values_callable=lambda enum_cls: [e.value for e in enum_cls], create_type=True),
        nullable=False,
        default=UserStatus.ACTIVE,
        server_default=UserStatus.ACTIVE.value,
        comment="Account lifecycle status",
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        comment="True after account verification",
    )

    # Relationships
    teacher: Mapped[Teacher | None] = relationship(
        "Teacher", foreign_keys=[teacher_id], lazy="joined"
    )
    parent: Mapped[Parent | None] = relationship(
        "Parent", foreign_keys=[parent_id], lazy="joined"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<User id={self.user_id!s} username={self.username!r} role={self.role!r}>"


# ===========================================================================
# School
# ===========================================================================


class School(Base, TimestampMixin):
    """Represents a kindergarten / preschool institution.

    Columns
    -------
    id           : UUID PK (auto-generated)
    name         : Full school name (unique, max 255 chars)
    code         : Short alphanumeric code, e.g. "KG-HCM-01" (unique, max 50)
    address      : Physical address (optional, free-text)
    phone        : Contact phone number (optional, max 20 chars)
    email        : Administrative email (optional, max 255 chars)
    status       : SchoolStatus enum – defaults to ACTIVE
    logo_url     : URL of the school logo stored in object storage (optional)

    Relationships
    -------------
    classes  : List[Class_]  – classes belonging to this school
    teachers : List[Teacher] – teachers whose primary school is this school
    """

    __tablename__ = "school"

    __table_args__ = (
        UniqueConstraint("code", name="uq_school_code"),
        UniqueConstraint("name", name="uq_school_name"),
        Index("ix_school_status", "status"),
        {"comment": "Kindergarten / preschool institutions registered in ADARK"},
    )

    # --- Primary key ---
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Core fields ---
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Full official name of the school",
    )
    code: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Short unique identifier used in reports, e.g. KG-HCM-01",
    )
    address: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Physical street address",
    )
    phone: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="Contact phone number",
    )
    email: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Administrative email address",
    )
    status: Mapped[SchoolStatus] = mapped_column(
        SAEnum(SchoolStatus, name="school_status_enum", create_type=True),
        nullable=False,
        default=SchoolStatus.ACTIVE,
        server_default=SchoolStatus.ACTIVE.value,
        comment="Lifecycle status of the school",
    )
    logo_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment="URL to the school logo image in object storage",
    )

    # --- Relationships ---
    classes: Mapped[list[Class_]] = relationship(
        "Class_",
        back_populates="school",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="Class_.name",
    )
    teachers: Mapped[list[Teacher]] = relationship(
        "Teacher",
        back_populates="school",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="Teacher.full_name",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return f"<School id={self.school_id!s} code={self.code!r} name={self.name!r}>"


# ===========================================================================
# Class_
# ===========================================================================


class Class_(Base, TimestampMixin):
    """A classroom / group within a School.

    The model name uses a trailing underscore (``Class_``) to avoid shadowing
    the Python built-in ``class`` keyword.  The database table is named
    ``class`` (no underscore) for a clean schema.

    Columns
    -------
    id         : UUID PK
    school_id  : FK → school.id  (CASCADE DELETE)
    name       : Class display name, e.g. "Lớp Mầm A" (max 100 chars)
    grade_label: Grade/age group label, e.g. "Mầm", "Chồi", "Lá" (max 50)
    room_number: Physical room identifier (optional, max 20 chars)
    capacity   : Maximum number of children (nullable)
    is_active  : Soft-delete / deactivation flag (default True)

    Relationships
    -------------
    school   : School          – owning school
    teachers : List[Teacher]   – teachers assigned to this class
    children : List[Child]     – children enrolled  (wired in TASK-1.2.2)
    """

    __tablename__ = "class"

    __table_args__ = (
        UniqueConstraint("school_id", "name", name="uq_class_school_name"),
        Index("ix_class_school_id", "school_id"),
        Index("ix_class_is_active", "is_active"),
        {"comment": "Classrooms / groups within a school"},
    )

    # --- Primary key ---
    class_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign key ---
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("school.school_id", ondelete="CASCADE", name="fk_class_school_id"),
        nullable=False,
        comment="Owning school – cascades delete",
    )

    # --- Core fields ---
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Display name of the class, e.g. Lớp Mầm A",
    )
    grade_label: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="Age/grade group label – Mầm | Chồi | Lá | Mẫu giáo",
    )
    room_number: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="Physical room number or identifier",
    )
    capacity: Mapped[int | None] = mapped_column(
        nullable=True,
        comment="Maximum number of children allowed in this class",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        comment="False = class is archived / no longer in use",
    )

    # --- Relationships ---
    school: Mapped[School] = relationship(
        "School",
        back_populates="classes",
        lazy="joined",
    )
    teachers: Mapped[list[Teacher]] = relationship(
        "Teacher",
        back_populates="class_",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="Teacher.full_name",
    )
    children: Mapped[list[Child]] = relationship(
        "Child",
        back_populates="class_",
        cascade="all, delete-orphan",
        lazy="select",
        order_by="Child.full_name",
    )
    voice_records: Mapped[list[VoiceRecord]] = relationship(
        "VoiceRecord",
        back_populates="class_",
        cascade="save-update, merge",  # FK is SET NULL – do NOT delete-orphan
        lazy="select",
        order_by="VoiceRecord.recorded_at",
    )
    broadcast_reports: Mapped[list[ClassBroadcastReport]] = relationship(
        "ClassBroadcastReport",
        back_populates="class_",
        cascade="save-update, merge",  # FK is SET NULL – do NOT delete-orphan
        lazy="select",
        order_by="ClassBroadcastReport.report_date",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return f"<Class_ id={self.class_id!s} name={self.name!r} school_id={self.school_id!s}>"


# ===========================================================================
# Teacher
# ===========================================================================


class Teacher(Base, TimestampMixin):
    """A teacher / educator who manages a Class_ and submits DailyReports.

    Columns
    -------
    id            : UUID PK
    school_id     : FK → school.id  (CASCADE DELETE)  – for direct school queries
    class_id      : FK → class.id   (SET NULL)        – current homeroom class
    full_name     : Teacher's full name (max 150 chars)
    email         : Login / contact email (unique, max 255 chars)
    phone         : Mobile phone (optional, max 20 chars)
    avatar_url    : Profile picture URL (optional, max 512 chars)
    status        : TeacherStatus enum
    is_verified   : Whether the account has been verified by school admin

    Relationships
    -------------
    school       : School         – direct school ref
    class_       : Class_         – homeroom class (nullable)
    voice_records: List[VoiceRecord]  – wired in TASK-1.2.3
    daily_reports: List[DailyReport] – wired in TASK-1.2.3
    """

    __tablename__ = "teacher"

    __table_args__ = (
        UniqueConstraint("email", name="uq_teacher_email"),
        Index("ix_teacher_school_id", "school_id"),
        Index("ix_teacher_class_id", "class_id"),
        Index("ix_teacher_email", "email"),
        Index("ix_teacher_status", "status"),
        {"comment": "Teachers / educators registered in ADARK"},
    )

    # --- Primary key ---
    teacher_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign keys ---
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("school.school_id", ondelete="CASCADE", name="fk_teacher_school_id"),
        nullable=False,
        comment="School the teacher belongs to",
    )
    class_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("class.class_id", ondelete="SET NULL", name="fk_teacher_class_id"),
        nullable=True,
        comment="Current homeroom class – NULL if not yet assigned",
    )

    # --- Personal info ---
    full_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        comment="Full display name",
    )
    email: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Login and contact email – must be unique",
    )
    phone: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="Mobile phone number",
    )
    avatar_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment="Profile picture URL in object storage",
    )

    # --- Status ---
    status: Mapped[TeacherStatus] = mapped_column(
        SAEnum(TeacherStatus, name="teacher_status_enum", create_type=True),
        nullable=False,
        default=TeacherStatus.ACTIVE,
        server_default=TeacherStatus.ACTIVE.value,
        comment="Employment / account status",
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="True after school admin approves the teacher account",
    )

    # --- Relationships ---
    school: Mapped[School] = relationship(
        "School",
        back_populates="teachers",
        lazy="joined",
    )
    class_: Mapped[Class_ | None] = relationship(
        "Class_",
        back_populates="teachers",
        lazy="joined",
    )
    voice_records: Mapped[list[VoiceRecord]] = relationship(
        "VoiceRecord",
        back_populates="teacher",
        cascade="all, delete-orphan",
        lazy="select",
        order_by="VoiceRecord.recorded_at",
    )
    daily_reports: Mapped[list[DailyReport]] = relationship(
        "DailyReport",
        back_populates="teacher",
        cascade="all, delete-orphan",
        lazy="select",
        order_by="DailyReport.report_date",
    )
    broadcast_reports: Mapped[list[ClassBroadcastReport]] = relationship(
        "ClassBroadcastReport",
        back_populates="teacher",
        cascade="all, delete-orphan",
        lazy="select",
        order_by="ClassBroadcastReport.report_date",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<Teacher id={self.teacher_id!s} email={self.email!r} "
            f"school_id={self.school_id!s} class_id={self.class_id!s}>"
        )

