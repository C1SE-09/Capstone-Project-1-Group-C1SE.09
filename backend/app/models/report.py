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
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    JSON,
    Date,
    DateTime,
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
    from app.models.user import Class_, Teacher


# ===========================================================================
# Enums
# ===========================================================================


class VoiceRecordScope(str, enum.Enum):
    """Scope of a VoiceRecord: single child or whole class.

    SINGLE_CHILD – audio recording for a single specific child.
    WHOLE_CLASS  – audio recording for an entire classroom / group.
    """

    SINGLE_CHILD = "single_child"
    WHOLE_CLASS = "whole_class"


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


class BroadcastReportStatus(str, enum.Enum):
    """Lifecycle status of a ClassBroadcastReport.

    DRAFT – created from class voice recording; draft state.
    SENT  – teacher approved and sent to parents of non-exception children.
    """

    DRAFT = "draft"
    SENT = "sent"


class DailyReportType(str, enum.Enum):
    """Origin/type of a DailyReport.

    INDIVIDUAL – standalone report created for a single child.
    EXCEPTION  – report separated out for a child with exception notes during a class recording.
    """

    INDIVIDUAL = "individual"
    EXCEPTION = "exception"


class DailyReportStatus(str, enum.Enum):
    """Lifecycle of a DailyReport

    DRAFT  - created from voice transcription; not yet reviewed by teacher.
    SENT   - teacher reviewed and sent it; the parent has been notified.
    READ   - the parent has opened it.
    ARCHIVED - no longer active (e.g. superseded by a correction).

    PUBLISHED is retained only so that un-migrated rows and older clients
    do not crash. It is deprecated - do not write it in new code.
    """

    DRAFT = "draft"
    SENT = "sent"
    READ = "read"
    ARCHIVED = "archived"
    PUBLISHED = "published"  # deprecated alias of SENT


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
        Index("ix_voice_record_class_id", "class_id"),
        Index("ix_voice_record_scope", "scope"),
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
        comment="Subject child of the recording – NULL if single_child or child deleted",
    )
    class_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "class.class_id",
            ondelete="SET NULL",
            name="fk_voice_record_class_id",
        ),
        nullable=True,
        comment="Target class for whole_class recording – NULL for single_child",
    )

    # --- Scope & Audio metadata ---
    scope: Mapped[VoiceRecordScope] = mapped_column(
        SAEnum(
            VoiceRecordScope,
            values_callable=lambda x: [e.value for e in x],
            name="voice_record_scope_enum",
            create_type=True,
        ),
        nullable=False,
        default=VoiceRecordScope.SINGLE_CHILD,
        server_default=VoiceRecordScope.SINGLE_CHILD.value,
        comment="Scope of recording: single_child or whole_class",
    )
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
        server_default=VoiceRecordStatus.PENDING.name,
        comment="Processing lifecycle status of the voice record",
    )
    error_message: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Error detail when status = FAILED; used for debugging and retries",
    )
    # --- AI extraction ---
    extraction_result: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="AI extraction result: {meals, sleeping, health, activities, mood}",
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
    class_: Mapped[Class_ | None] = relationship(
        "Class_",
        back_populates="voice_records",
        lazy="joined",
    )
    daily_report: Mapped[DailyReport | None] = relationship(
        "DailyReport",
        back_populates="voice_record",
        uselist=False,  # 1-to-1: one VoiceRecord → at most one DailyReport
        lazy="selectin",
    )
    broadcast_report: Mapped[ClassBroadcastReport | None] = relationship(
        "ClassBroadcastReport",
        back_populates="voice_record",
        uselist=False,  # 1-to-1: one VoiceRecord → at most one ClassBroadcastReport
        lazy="select",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<VoiceRecord id={self.voice_record_id!s} scope={self.scope.value!r} "
            f"status={self.status.value!r} teacher_id={self.teacher_id!s}>"
        )


# ===========================================================================
# ClassBroadcastReport
# ===========================================================================


class ClassBroadcastReport(Base, TimestampMixin):
    """A broadcast daily report for an entire classroom / group.

    Generated when a teacher submits a whole_class voice recording.
    Summarizes common daily activities (meals, nap, health, activities, mood)
    sent to all parents whose child doesn't have an individual exception report.

    Columns
    -------
    broadcast_report_id : UUID PK (auto-generated)
    voice_record_id     : FK → voice_record.voice_record_id (SET NULL)
    class_id            : FK → class.class_id               (SET NULL)
    teacher_id          : FK → teacher.teacher_id           (SET NULL)
    report_date         : Calendar date of the broadcast report
    common_meals        : AI-generated/teacher-edited common meal info (nullable)
    common_sleeping     : AI-generated/teacher-edited common nap info (nullable)
    common_health       : AI-generated/teacher-edited common health info (nullable)
    common_activities   : AI-generated/teacher-edited common activities (nullable)
    common_mood         : AI-generated/teacher-edited common mood (nullable)
    common_notes        : Additional general notes (nullable)
    included_child_ids  : JSON list of child_id strings receiving this broadcast
    excluded_child_ids  : JSON list of child_id strings separated into exception reports
    status              : BroadcastReportStatus (DRAFT / SENT)
    sent_at             : UTC timestamp when published/sent to parents

    Relationships
    -------------
    teacher           : Teacher           – report author
    class_            : Class_            – target classroom
    voice_record      : VoiceRecord | None – source audio record
    exception_reports : List[DailyReport] – individual reports for excluded children
    """

    __tablename__ = "class_broadcast_report"

    __table_args__ = (
        UniqueConstraint(
            "class_id",
            "report_date",
            name="uq_broadcast_class_date",
        ),
        Index("ix_broadcast_class_id", "class_id"),
        Index("ix_broadcast_teacher_id", "teacher_id"),
        Index("ix_broadcast_report_date", "report_date"),
        Index("ix_broadcast_status", "status"),
        {"comment": "Broadcast daily reports summarizing common class activities"},
    )

    # --- Primary key ---
    broadcast_report_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign keys ---
    voice_record_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "voice_record.voice_record_id",
            ondelete="SET NULL",
            name="fk_broadcast_voice_record_id",
        ),
        nullable=True,
        comment="Source voice recording – NULL if created manually",
    )
    class_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "class.class_id",
            ondelete="SET NULL",
            name="fk_broadcast_class_id",
        ),
        nullable=True,
        comment="Class receiving this broadcast report",
    )
    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "teacher.teacher_id",
            ondelete="SET NULL",
            name="fk_broadcast_teacher_id",
        ),
        nullable=True,
        comment="Teacher who created the broadcast report",
    )

    # --- Content ---
    report_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Calendar date covered by this broadcast report",
    )
    common_meals: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Common meal information for the whole class",
    )
    common_sleeping: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Common sleep/nap information for the whole class",
    )
    common_health: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Common health information for the whole class",
    )
    common_activities: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Common learning/play activities for the whole class",
    )
    common_mood: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Common mood/general sentiment for the whole class",
    )
    common_notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="General notes or extra reminders for parents",
    )

    # --- Recipient lists ---
    included_child_ids: Mapped[list[str] | dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="List of child IDs (UUID strings) receiving the broadcast report",
    )
    excluded_child_ids: Mapped[list[str] | dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="List of child IDs (UUID strings) with individual exception reports",
    )

    # --- Status ---
    status: Mapped[BroadcastReportStatus] = mapped_column(
        SAEnum(
            BroadcastReportStatus,
            values_callable=lambda x: [e.value for e in x],
            name="broadcast_report_status_enum",
            create_type=True,
        ),
        nullable=False,
        default=BroadcastReportStatus.DRAFT,
        server_default=BroadcastReportStatus.DRAFT.value,
        comment="Publication lifecycle: draft → sent",
    )
    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="UTC timestamp when the broadcast report was sent to parents",
    )

    # --- Relationships ---
    teacher: Mapped[Teacher | None] = relationship(
        "Teacher",
        back_populates="broadcast_reports",
        lazy="select",
    )
    class_: Mapped[Class_ | None] = relationship(
        "Class_",
        back_populates="broadcast_reports",
        lazy="select",
    )
    voice_record: Mapped[VoiceRecord | None] = relationship(
        "VoiceRecord",
        back_populates="broadcast_report",
        lazy="select",
    )
    exception_reports: Mapped[list[DailyReport]] = relationship(
        "DailyReport",
        back_populates="source_broadcast",
        cascade="all, delete-orphan",
        lazy="select",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<ClassBroadcastReport id={self.broadcast_report_id!s} "
            f"class_id={self.class_id!s} date={self.report_date!s} "
            f"status={self.status.value!r}>"
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
    daily_report_id     : UUID PK
    teacher_id          : FK → teacher.teacher_id (SET NULL)
    child_id            : FK → child.child_id     (SET NULL)
    voice_record_id     : FK → voice_record.voice_record_id (SET NULL, optional)
    source_broadcast_id : FK → class_broadcast_report.broadcast_report_id (SET NULL, optional)
    report_type         : DailyReportType (individual | exception)
    report_date         : Calendar date of the report (indexed for date queries)
    summary_text        : AI-generated or teacher-edited summary (Text, nullable)
    status              : DailyReportStatus – draft/published/archived
    published_at        : Timestamp when teacher published the report (nullable)
    Constraints
    -----------
    uq_daily_report_child_date : UNIQUE (child_id, report_date)
        Enforces one report per child per day at the DB level.

    Relationships
    -------------
    teacher          : Teacher              – report author (nullable after deletion)
    child            : Child                – subject child (nullable after deletion)
    voice_record     : VoiceRecord | None   – source audio record (optional)
    source_broadcast : ClassBroadcastReport – parent broadcast report if exception type
    activities       : List[ActivityEntry]  – ordered activity items in this report
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
        Index("ix_daily_report_report_type", "report_type"),
        Index("ix_daily_report_source_broadcast_id", "source_broadcast_id"),
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
    source_broadcast_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "class_broadcast_report.broadcast_report_id",
            ondelete="SET NULL",
            name="fk_daily_report_source_broadcast_id",
        ),
        nullable=True,
        comment="Linked broadcast report if this report was generated as an exception from a class recording",
    )

    # --- Report type & content ---
    report_type: Mapped[DailyReportType] = mapped_column(
        SAEnum(
            DailyReportType,
            values_callable=lambda x: [e.value for e in x],
            name="daily_report_type_enum",
            create_type=True,
        ),
        nullable=False,
        default=DailyReportType.INDIVIDUAL,
        server_default=DailyReportType.INDIVIDUAL.value,
        comment="Origin type: individual (standalone single-child) or exception (separated from class broadcast)",
    )
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
        server_default=DailyReportStatus.DRAFT.name,
        comment="Publication lifecycle: draft → sent → read → archived",
    )
    published_at: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        comment="Date the teacher published (sent) the report to the parent",
    )
    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="UTC timestamp when the teacher sent the report to the parent",
    )
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="UTC timestamp when the parent first opened the report",
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
    source_broadcast: Mapped[ClassBroadcastReport | None] = relationship(
        "ClassBroadcastReport",
        back_populates="exception_reports",
        lazy="select",
    )
    activities: Mapped[list[ActivityEntry]] = relationship(
        "ActivityEntry",
        back_populates="daily_report",
        cascade="all, delete-orphan",
        lazy="select",
        order_by="ActivityEntry.entry_order",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<DailyReport id={self.daily_report_id!s} "
            f"child_id={self.child_id!s} date={self.report_date!s} "
            f"type={self.report_type.value!r} status={self.status.value!r}>"
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
        server_default=ActivityCategory.OTHER.name,
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
