"""
app/models/bug_report.py
========================
SQLAlchemy 2.0 ORM Models: BugReport, BugReportAttachment, BugReportHistory
-------------------------------------------------------------------------
Entity hierarchy
~~~~~~~~~~~~~~~~
    BugReport  1──*  BugReportAttachment  (screenshots, logs)
    BugReport  1──*  BugReportHistory    (status change audit trail)

Design decisions
~~~~~~~~~~~~~~~~
* Uses SQLAlchemy 2.0 **Mapped / mapped_column** annotation style (fully type-safe).
* All PKs use ``uuid.UUID`` stored as native PostgreSQL ``UUID`` column.
* ``TimestampMixin`` injects ``created_at`` / ``updated_at`` from ``base.py``.
* ``__table_args__`` carries database-level constraints and indexes.
* Enum columns use Python ``enum.Enum`` + SQLAlchemy ``Enum`` type so values
  are validated both in Python and at the database layer.
* ``BugReportHistory`` records every status/assignment change for audit purposes.
* Attachments are stored in MinIO (S3-compatible) and referenced by URL.
* Foreign keys use ``SET NULL`` on parent deletion so that a deleted user or
  teacher still leaves the bug report intact for admin review.

TASK: TASK-B-01 – Bug Report Models
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
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
    from app.models.user import Teacher, User


# ===========================================================================
# Enums
# ===========================================================================


class BugCategory(str, enum.Enum):
    """Category / type of the bug as reported by the user."""

    UI = "ui"  # Giao diện / UI bị lỗi
    PERFORMANCE = "performance"  # Chậm / lag
    CRASH = "crash"  # App bị crash / đóng băng
    DATA = "data"  # Sai dữ liệu / mất dữ liệu
    NOTIFICATION = "notification"  # Thông báo không gửi được
    NETWORK = "network"  # Lỗi kết nối mạng
    AUTH = "auth"  # Lỗi đăng nhập / xác thực
    OTHER = "other"  # Lỗi khác


class BugSeverity(str, enum.Enum):
    """Severity level of the bug – used for triaging."""

    LOW = "low"  # Không ảnh hưởng nhiều
    MEDIUM = "medium"  # Ảnh hưởng một phần
    HIGH = "high"  # Ảnh hưởng lớn, cần sửa sớm
    CRITICAL = "critical"  # App không thể dùng được


class BugStatus(str, enum.Enum):
    """Lifecycle status of a BugReport."""

    OPEN = "open"  # Mới được gửi, chưa xem
    IN_PROGRESS = "in_progress"  # Đang được xử lý
    RESOLVED = "resolved"  # Đã sửa xong, chờ user xác nhận
    CLOSED = "closed"  # User xác nhận đã ok / admin đóng
    WONT_FIX = "wont_fix"  # Không sửa (wontfix / duplicate / outside scope)


# ===========================================================================
# BugReport
# ===========================================================================


class BugReport(Base, TimestampMixin):
    """A bug / issue report submitted by a parent, teacher, or admin.

    Users can attach screenshots and device logs to help with debugging.
    Every status change is recorded in BugReportHistory for audit.

    Columns
    -------
    bug_report_id   : UUID PK (auto-generated)
    user_id        : FK → users.user_id (SET NULL) – reporter
    teacher_id     : FK → teacher.teacher_id (SET NULL) – assignee (optional)
    title          : Short summary of the bug (max 200 chars)
    description    : Detailed description (Text)
    category       : BugCategory enum
    severity       : BugSeverity enum
    status         : BugStatus enum – defaults to OPEN
    app_version    : Flutter app version string, e.g. "1.2.3" (optional)
    build_number   : Build number, e.g. "42" (optional)
    os_version     : Device OS version, e.g. "Android 14" (optional)
    device_model   : Device model, e.g. "Samsung Galaxy S23" (optional)
    network_type   : Network type when bug occurred: wifi/cellular/offline (optional)
    resolved_at    : UTC timestamp when status became RESOLVED (nullable)
    closed_at      : UTC timestamp when status became CLOSED (nullable)

    Relationships
    -------------
    user         : User         – person who submitted the report
    teacher      : Teacher | None – assigned developer/teacher (nullable)
    attachments  : List[BugReportAttachment] – screenshots / logs
    history      : List[BugReportHistory]    – audit trail of changes
    """

    __tablename__ = "bug_report"

    __table_args__ = (
        Index("ix_bug_report_user_id", "user_id"),
        Index("ix_bug_report_teacher_id", "teacher_id"),
        Index("ix_bug_report_status", "status"),
        Index("ix_bug_report_severity", "severity"),
        Index("ix_bug_report_category", "category"),
        Index("ix_bug_report_created_at", "created_at"),
        Index("ix_bug_report_app_version", "app_version"),
        {"comment": "Bug/issue reports submitted by app users"},
    )

    # --- Primary key ---
    bug_report_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign keys ---
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "users.user_id",
            ondelete="SET NULL",
            name="fk_bug_report_user_id",
        ),
        nullable=False,
        comment="User who reported the bug – NULL if user is deleted",
    )
    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "teacher.teacher_id",
            ondelete="SET NULL",
            name="fk_bug_report_teacher_id",
        ),
        nullable=True,
        comment="Assigned developer/teacher – NULL if not yet assigned",
    )

    # --- Content ---
    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
        comment="Short summary of the bug, e.g. 'App crash khi mở thông báo'",
    )
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Detailed description of what happened, steps to reproduce, etc.",
    )
    category: Mapped[BugCategory] = mapped_column(
        SAEnum(
            BugCategory,
            values_callable=lambda x: [e.value for e in x],
            name="bug_category_enum",
            create_type=True,
        ),
        nullable=False,
        default=BugCategory.OTHER,
        server_default=BugCategory.OTHER.value,
        comment="Type/category of the bug",
    )
    severity: Mapped[BugSeverity] = mapped_column(
        SAEnum(
            BugSeverity,
            values_callable=lambda x: [e.value for e in x],
            name="bug_severity_enum",
            create_type=True,
        ),
        nullable=False,
        default=BugSeverity.MEDIUM,
        server_default=BugSeverity.MEDIUM.value,
        comment="Severity level for triaging",
    )
    status: Mapped[BugStatus] = mapped_column(
        SAEnum(
            BugStatus,
            values_callable=lambda x: [e.value for e in x],
            name="bug_status_enum",
            create_type=True,
        ),
        nullable=False,
        default=BugStatus.OPEN,
        server_default=BugStatus.OPEN.value,
        comment="Current lifecycle status of the bug report",
    )

    # --- Device & environment info ---
    app_version: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="Flutter app version, e.g. '1.2.3'",
    )
    build_number: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="Build number, e.g. '42'",
    )
    os_version: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Device OS version, e.g. 'Android 14' or 'iOS 17.2'",
    )
    device_model: Mapped[str | None] = mapped_column(
        String(200),
        nullable=True,
        comment="Device model name, e.g. 'Samsung Galaxy S23'",
    )
    network_type: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="Network type when bug occurred: wifi | cellular | offline",
    )

    # --- Resolution timestamps ---
    resolved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="UTC timestamp when the bug was marked as resolved",
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="UTC timestamp when the bug report was closed",
    )

    # --- Relationships ---
    user: Mapped[User] = relationship(
        "User",
        lazy="joined",
    )
    teacher: Mapped[Teacher | None] = relationship(
        "Teacher",
        lazy="joined",
    )
    attachments: Mapped[list[BugReportAttachment]] = relationship(
        "BugReportAttachment",
        back_populates="report",
        cascade="all, delete-orphan",
        lazy="select",
        order_by="BugReportAttachment.created_at",
    )
    history: Mapped[list[BugReportHistory]] = relationship(
        "BugReportHistory",
        back_populates="report",
        cascade="all, delete-orphan",
        lazy="select",
        order_by="BugReportHistory.created_at",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<BugReport id={self.bug_report_id!s} "
            f"title={self.title!r} status={self.status.value!r} "
            f"severity={self.severity.value!r}>"
        )


# ===========================================================================
# BugReportAttachment
# ===========================================================================


class BugReportAttachment(Base, TimestampMixin):
    """A file attachment (screenshot, log) associated with a BugReport.

    Files are stored in MinIO (S3-compatible object storage) and referenced
    by their pre-signed or public URL.

    Columns
    -------
    attachment_id  : UUID PK (auto-generated)
    bug_report_id : FK → bug_report.bug_report_id (CASCADE DELETE)
    file_url      : Full URL to the file in MinIO (max 512 chars)
    file_name     : Original file name (max 255 chars)
    file_size     : File size in bytes (optional)
    mime_type     : MIME type, e.g. "image/png", "text/plain" (optional)
    description   : Optional description of what this attachment shows (optional)

    Relationships
    -------------
    report : BugReport – parent bug report
    """

    __tablename__ = "bug_report_attachment"

    __table_args__ = (
        Index("ix_bug_report_attachment_report_id", "bug_report_id"),
        {"comment": "File attachments (screenshots, logs) for bug reports"},
    )

    # --- Primary key ---
    attachment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign key ---
    bug_report_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "bug_report.bug_report_id",
            ondelete="CASCADE",
            name="fk_bug_report_attachment_report_id",
        ),
        nullable=False,
        comment="Parent bug report – cascades delete",
    )

    # --- File metadata ---
    file_url: Mapped[str] = mapped_column(
        String(512),
        nullable=False,
        comment="Full URL to the file in MinIO / S3",
    )
    file_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Original file name as uploaded, e.g. 'screenshot_2024.png'",
    )
    file_size: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="File size in bytes",
    )
    mime_type: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="MIME type, e.g. 'image/png' or 'text/plain'",
    )
    description: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
        comment="Optional description of what this attachment shows",
    )

    # --- Relationships ---
    report: Mapped[BugReport] = relationship(
        "BugReport",
        back_populates="attachments",
        lazy="joined",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<BugReportAttachment id={self.attachment_id!s} "
            f"file_name={self.file_name!r} mime_type={self.mime_type!r}>"
        )


# ===========================================================================
# BugReportHistory
# ===========================================================================


class BugReportHistory(Base, TimestampMixin):
    """Audit trail entry for a BugReport status or assignment change.

    Every time the status or assignee changes, a new history record is created.
    This provides a complete timeline for transparency and debugging.

    Columns
    -------
    history_id    : UUID PK (auto-generated)
    bug_report_id : FK → bug_report.bug_report_id (CASCADE DELETE)
    changed_by_id : FK → users.user_id (SET NULL) – who made the change
    old_status    : Previous BugStatus (nullable for first entry)
    new_status    : New BugStatus (nullable if only assignee changed)
    old_teacher_id: Previous assigned teacher (nullable)
    new_teacher_id: New assigned teacher (nullable)
    comment       : Optional note from the user/admin about this change (optional)

    Relationships
    -------------
    report    : BugReport – parent bug report
    changed_by: User | None – user who made the change
    """

    __tablename__ = "bug_report_history"

    __table_args__ = (
        Index("ix_bug_report_history_report_id", "bug_report_id"),
        Index("ix_bug_report_history_changed_by_id", "changed_by_id"),
        Index("ix_bug_report_history_created_at", "created_at"),
        {"comment": "Audit trail of status and assignment changes for bug reports"},
    )

    # --- Primary key ---
    history_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign keys ---
    bug_report_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "bug_report.bug_report_id",
            ondelete="CASCADE",
            name="fk_bug_report_history_report_id",
        ),
        nullable=False,
        comment="Parent bug report – cascades delete",
    )
    changed_by_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "users.user_id",
            ondelete="SET NULL",
            name="fk_bug_report_history_changed_by_id",
        ),
        nullable=True,
        comment="User who made this change – NULL if user is deleted",
    )

    # --- Status change ---
    old_status: Mapped[BugStatus | None] = mapped_column(
        SAEnum(
            BugStatus,
            values_callable=lambda x: [e.value for e in x],
            name="bug_status_enum",
            create_type=False,  # Already created by BugReport
        ),
        nullable=True,
        comment="Previous status before this change (NULL for initial OPEN)",
    )
    new_status: Mapped[BugStatus | None] = mapped_column(
        SAEnum(
            BugStatus,
            values_callable=lambda x: [e.value for e in x],
            name="bug_status_enum",
            create_type=False,
        ),
        nullable=True,
        comment="New status after this change (NULL if only assignee changed)",
    )

    # --- Assignment change ---
    old_teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "teacher.teacher_id",
            ondelete="SET NULL",
            name="fk_bug_report_history_old_teacher_id",
        ),
        nullable=True,
        comment="Previous assigned teacher before this change",
    )
    new_teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "teacher.teacher_id",
            ondelete="SET NULL",
            name="fk_bug_report_history_new_teacher_id",
        ),
        nullable=True,
        comment="New assigned teacher after this change",
    )

    # --- Note ---
    comment: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Optional note explaining why the change was made",
    )

    # --- Relationships ---
    report: Mapped[BugReport] = relationship(
        "BugReport",
        back_populates="history",
        lazy="joined",
    )
    changed_by: Mapped[User | None] = relationship(
        "User",
        lazy="joined",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<BugReportHistory id={self.history_id!s} "
            f"report_id={self.bug_report_id!s} "
            f"old={self.old_status.value if self.old_status else None!r} "
            f"→ new={self.new_status.value if self.new_status else None!r}>"
        )
