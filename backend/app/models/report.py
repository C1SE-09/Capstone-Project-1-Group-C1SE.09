"""
app/models/report.py
====================
SQLAlchemy 2.0 ORM Models: VoiceRecord, DailyReport, ActivityEntry
--------------------------------------------------------------------
Entity hierarchy
~~~~~~~~~~~~~~~~
    Teacher     1──*  VoiceRecord     (teacher records audio → transcription)
    Teacher     1──*  DailyReport     (teacher submits daily reports for a class)
    Child       1──*  DailyReport     (one report per child per day)
    DailyReport 1──*  ActivityEntry   (individual activity items within a report)

Design decisions
~~~~~~~~~~~~~~~~
* Uses SQLAlchemy 2.0 **Mapped / mapped_column** annotation style (fully type-safe).
* All PKs use ``uuid.UUID`` stored as native PostgreSQL ``UUID`` column.
* ``TimestampMixin`` injects ``created_at`` / ``updated_at`` from ``base.py``.
* ``__table_args__`` carries database-level constraints and indexes.
* Enum columns use Python ``enum.Enum`` + SQLAlchemy ``Enum`` type so values
  are validated both in Python and at the database layer.
* ``VoiceRecord.transcription`` and ``DailyReport.summary_text`` use ``Text``
  columns (unlimited length) for AI-generated content.
* ``DailyReport`` has a ``UniqueConstraint`` on (child_id, report_date) to
  enforce one report per child per day at the database level.
* ``ActivityEntry.entry_order`` is an integer used to preserve the sequence of
  activity items within a report (e.g., breakfast → nap → lunch).
* ``back_populates`` wires bidirectional relationships without circular imports
  because Teacher / Child live in separate files (user.py, child.py).

TASK: TASK-1.2.3 – Voice & Daily Report Models
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
    Integer,
    SmallInteger,
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
    from app.models.child import Child
    from app.models.user import Teacher


# ===========================================================================
# Enums
# ===========================================================================


class VoiceRecordStatus(str, enum.Enum):
    """Processing lifecycle of a VoiceRecord.

    PENDING     – audio uploaded, waiting to be processed by the AI pipeline.
    PROCESSING  – Gemini / STT pipeline is currently transcribing.
    COMPLETED   – transcription ready; DailyReport may have been generated.
    FAILED      – processing failed (see ``error_message`` column).
    """

    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class DailyReportStatus(str, enum.Enum):
    """Publication lifecycle of a DailyReport.

    DRAFT       – created from voice transcription; not yet reviewed by teacher.
    PUBLISHED   – teacher has reviewed and sent to parents.
    ARCHIVED    – report is no longer active (e.g., corrected by a newer one).
    """

    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class ActivityCategory(str, enum.Enum):
    """Broad category of an ActivityEntry within a daily report.

    Maps to common kindergarten activity types used in Vietnam's preschool
    curriculum (Chương trình GDMN).
    """

    MEAL = "meal"  # Bữa ăn
    NAP = "nap"  # Giấc ngủ
    LEARNING = "learning"  # Hoạt động học tập
    PLAY = "play"  # Hoạt động vui chơi
    HEALTH = "health"  # Sức khỏe / y tế
    BEHAVIOR = "behavior"  # Hành vi / cảm xúc
    OTHER = "other"  # Khác


# ===========================================================================
# VoiceRecord
# ===========================================================================


class VoiceRecord(Base, TimestampMixin):
    """Raw audio recording uploaded by a Teacher before AI processing.

    A teacher records a voice note describing a child's day.  The audio file
    is stored in object storage (S3-compatible) and its URL is persisted here.
    An asynchronous Celery task picks up PENDING records, calls the Gemini
    Speech-to-Text pipeline, and writes the transcription back before
    creating/updating the corresponding DailyReport.

    Columns
    -------
    voice_record_id : UUID PK (auto-generated)
    teacher_id      : FK → teacher.teacher_id  (SET NULL on teacher deletion)
    child_id        : FK → child.child_id      (SET NULL on child deletion)
    audio_url       : Object-storage URL of the uploaded audio file (max 512)
    audio_duration  : Duration in seconds (float, optional)
    file_size_bytes : Raw file size in bytes (optional, for storage reporting)
    transcription   : AI-generated text transcript (nullable until COMPLETED)
    status          : VoiceRecordStatus – processing lifecycle
    error_message   : Set when status = FAILED to assist debugging (optional)
    recorded_at     : Client-reported timestamp of the recording (optional)

    Relationships
    -------------
    teacher      : Teacher          – teacher who uploaded the recording
    child        : Child            – subject child of the recording
    daily_report : DailyReport | None – report generated from this recording
    """

    __tablename__ = "voice_record"

    __table_args__ = (
        Index("ix_voice_record_teacher_id", "teacher_id"),
        Index("ix_voice_record_child_id", "child_id"),
        Index("ix_voice_record_status", "status"),
        Index("ix_voice_record_recorded_at", "recorded_at"),
        {"comment": "Raw audio recordings uploaded by teachers for AI transcription"},
    )

    # --- Primary key ---
    voice_record_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign keys ---
    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "teacher.teacher_id",
            ondelete="SET NULL",
            name="fk_voice_record_teacher_id",
        ),
        nullable=True,
        comment="Teacher who uploaded the recording – NULL if teacher is deleted",
    )
    child_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "child.child_id",
            ondelete="SET NULL",
            name="fk_voice_record_child_id",
        ),
        nullable=True,
        comment="Subject child of the recording – NULL if child is deleted",
    )

    # --- Audio metadata ---
    audio_url: Mapped[str] = mapped_column(
        String(512),
        nullable=False,
        comment="Object-storage URL of the uploaded audio file",
    )
    audio_duration: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Duration of the audio clip in seconds",
    )
    file_size_bytes: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Raw file size in bytes – used for storage quota reporting",
    )

    # --- AI processing ---
    raw_transcript: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Original AI speech-to-text transcript; NULL until COMPLETED",
    )
    edited_transcript: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Teacher-edited transcript; NULL if not manually edited",
    )
    transcription: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Legacy/fallback transcript field; mirrors raw_transcript",
    )
    status: Mapped[VoiceRecordStatus] = mapped_column(
        SAEnum(VoiceRecordStatus, name="voice_record_status_enum", create_type=True),
        nullable=False,
        default=VoiceRecordStatus.PENDING,
        server_default=VoiceRecordStatus.PENDING.value,
        comment="Processing lifecycle status of the voice record",
    )
    error_message: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Error detail when status = FAILED; used for debugging and retries",
    )

    # --- Timestamps ---
    recorded_at: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        comment="Client-reported date of the recording (usually today's date)",
    )

    # --- Relationships ---
    teacher: Mapped[Teacher | None] = relationship(
        "Teacher",
        back_populates="voice_records",
        lazy="joined",
    )
    child: Mapped[Child | None] = relationship(
        "Child",
        back_populates="voice_records",
        lazy="joined",
    )
    daily_report: Mapped[DailyReport | None] = relationship(
        "DailyReport",
        back_populates="voice_record",
        uselist=False,  # 1-to-1: one VoiceRecord → at most one DailyReport
        lazy="selectin",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<VoiceRecord id={self.voice_record_id!s} "
            f"status={self.status.value!r} teacher_id={self.teacher_id!s}>"
        )


# ===========================================================================
# DailyReport
# ===========================================================================


class DailyReport(Base, TimestampMixin):
    """A structured daily report for a single child on a specific date.

    Generated (initially as a DRAFT) by the AI pipeline after transcribing a
    VoiceRecord.  The teacher reviews the draft in the app and PUBLISHES it,
    which triggers a push notification to the child's parent.

    Columns
    -------
    daily_report_id  : UUID PK
    teacher_id       : FK → teacher.teacher_id (SET NULL)
    child_id         : FK → child.child_id     (SET NULL)
    voice_record_id  : FK → voice_record.voice_record_id (SET NULL, optional)
    report_date      : Calendar date of the report (indexed for date queries)
    summary_text     : AI-generated or teacher-edited summary (Text, nullable)
    status           : DailyReportStatus – draft/published/archived
    published_at     : Timestamp when teacher published the report (nullable)

    Constraints
    -----------
    uq_daily_report_child_date : UNIQUE (child_id, report_date)
        Enforces one report per child per day at the DB level.

    Relationships
    -------------
    teacher      : Teacher              – report author (nullable after deletion)
    child        : Child                – subject child (nullable after deletion)
    voice_record : VoiceRecord | None   – source audio record (optional)
    activities   : List[ActivityEntry]  – ordered activity items in this report
    """

    __tablename__ = "daily_report"

    __table_args__ = (
        UniqueConstraint(
            "child_id",
            "report_date",
            name="uq_daily_report_child_date",
        ),
        Index("ix_daily_report_teacher_id", "teacher_id"),
        Index("ix_daily_report_child_id", "child_id"),
        Index("ix_daily_report_report_date", "report_date"),
        Index("ix_daily_report_status", "status"),
        {"comment": "Structured daily reports submitted by teachers for each child"},
    )

    # --- Primary key ---
    daily_report_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign keys ---
    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "teacher.teacher_id",
            ondelete="SET NULL",
            name="fk_daily_report_teacher_id",
        ),
        nullable=True,
        comment="Teacher who authored the report – NULL if teacher is deleted",
    )
    child_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "child.child_id",
            ondelete="SET NULL",
            name="fk_daily_report_child_id",
        ),
        nullable=True,
        comment="Subject child – NULL if child record is deleted",
    )
    voice_record_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "voice_record.voice_record_id",
            ondelete="SET NULL",
            name="fk_daily_report_voice_record_id",
        ),
        nullable=True,
        comment="Source voice recording – NULL for manually authored reports",
    )

    # --- Report content ---
    report_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Calendar date the report covers (used in UniqueConstraint with child_id)",
    )
    summary_text: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="AI-generated or teacher-edited narrative summary of the child's day",
    )

    # --- Status ---
    status: Mapped[DailyReportStatus] = mapped_column(
        SAEnum(DailyReportStatus, name="daily_report_status_enum", create_type=True),
        nullable=False,
        default=DailyReportStatus.DRAFT,
        server_default=DailyReportStatus.DRAFT.value,
        comment="Publication lifecycle: draft → published → archived",
    )
    published_at: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        comment="Date the teacher published (sent) the report to the parent",
    )

    # --- Relationships ---
    teacher: Mapped[Teacher | None] = relationship(
        "Teacher",
        back_populates="daily_reports",
        lazy="joined",
    )
    child: Mapped[Child | None] = relationship(
        "Child",
        back_populates="daily_reports",
        lazy="joined",
    )
    voice_record: Mapped[VoiceRecord | None] = relationship(
        "VoiceRecord",
        back_populates="daily_report",
        lazy="joined",
    )
    activities: Mapped[list[ActivityEntry]] = relationship(
        "ActivityEntry",
        back_populates="daily_report",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="ActivityEntry.entry_order",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<DailyReport id={self.daily_report_id!s} "
            f"child_id={self.child_id!s} date={self.report_date!s} "
            f"status={self.status.value!r}>"
        )


# ===========================================================================
# ActivityEntry
# ===========================================================================


class ActivityEntry(Base, TimestampMixin):
    """An individual activity item within a DailyReport.

    The AI pipeline extracts structured activity blocks from the teacher's
    voice transcription (e.g., "bé ăn hết suất cơm trưa" → MEAL entry).
    Teachers can edit, reorder, add, or delete entries before publishing.

    Columns
    -------
    activity_entry_id : UUID PK
    daily_report_id   : FK → daily_report.daily_report_id (CASCADE DELETE)
    category          : ActivityCategory enum – type of activity
    title             : Short heading, e.g. "Bữa trưa" (max 150 chars)
    description       : Detailed narrative of the activity (Text, nullable)
    entry_order       : Integer sort key to preserve display sequence (default 0)
    icon_code         : Optional icon identifier used in the Flutter UI (max 50)

    Relationships
    -------------
    daily_report : DailyReport – parent report that owns this entry
    """

    __tablename__ = "activity_entry"

    __table_args__ = (
        Index("ix_activity_entry_daily_report_id", "daily_report_id"),
        Index("ix_activity_entry_category", "category"),
        {
            "comment": (
                "Individual activity entries extracted from a teacher's voice report"
            )
        },
    )

    # --- Primary key ---
    activity_entry_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign key ---
    daily_report_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "daily_report.daily_report_id",
            ondelete="CASCADE",
            name="fk_activity_entry_daily_report_id",
        ),
        nullable=False,
        comment="Parent daily report – cascades delete when report is removed",
    )

    # --- Activity details ---
    category: Mapped[ActivityCategory] = mapped_column(
        SAEnum(ActivityCategory, name="activity_category_enum", create_type=True),
        nullable=False,
        default=ActivityCategory.OTHER,
        server_default=ActivityCategory.OTHER.value,
        comment="Broad activity type (meal | nap | learning | play | health | behavior | other)",
    )
    title: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        comment="Short heading shown in the report card, e.g. 'Bữa trưa'",
    )
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Detailed narrative text for this activity item",
    )
    entry_order: Mapped[int] = mapped_column(
        SmallInteger,
        nullable=False,
        default=0,
        server_default="0",
        comment="Display sort order within the daily report (ascending)",
    )
    icon_code: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="Optional icon identifier used by the Flutter client (e.g. 'meal_fork')",
    )

    # --- Relationships ---
    daily_report: Mapped[DailyReport] = relationship(
        "DailyReport",
        back_populates="activities",
        lazy="joined",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<ActivityEntry id={self.activity_entry_id!s} "
            f"category={self.category.value!r} order={self.entry_order} "
            f"report_id={self.daily_report_id!s}>"
        )
