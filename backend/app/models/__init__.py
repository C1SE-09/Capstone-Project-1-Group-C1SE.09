"""
app/models/__init__.py
======================
Re-exports all ORM model classes so that Alembic's ``env.py`` and other
modules can import from a single location:

    from app.models import (
        Base, School, Class_, Teacher,
        Child, Parent,
        VoiceRecord, DailyReport, ActivityEntry,
    )

Import order matters: Base must be imported before any model so that
SQLAlchemy's mapper registry is populated correctly.
"""

from app.models.base import Base, TimestampMixin
from app.models.child import (
    Child,
    ChildStatus,
    Parent,
    ParentStatus,
)
from app.models.report import (
    ActivityCategory,
    ActivityEntry,
    BroadcastReportStatus,
    ClassBroadcastReport,
    DailyReport,
    DailyReportStatus,
    DailyReportType,
    VoiceRecord,
    VoiceRecordScope,
    VoiceRecordStatus,
)
from app.models.user import (
    Class_,
    School,
    SchoolStatus,
    Teacher,
    TeacherStatus,
    User,
    UserRole,
    UserStatus,
)

__all__ = [
    "ActivityCategory",
    "ActivityEntry",
    "Base",
    "BroadcastReportStatus",
    "Child",
    "ChildStatus",
    "ClassBroadcastReport",
    "Class_",
    "DailyReport",
    "DailyReportStatus",
    "DailyReportType",
    "Parent",
    "ParentStatus",
    "School",
    "SchoolStatus",
    "Teacher",
    "TeacherStatus",
    "TimestampMixin",
    "User",
    "UserRole",
    "UserStatus",
    "VoiceRecord",
    "VoiceRecordScope",
    "VoiceRecordStatus",
]
