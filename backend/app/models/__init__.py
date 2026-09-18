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

from backend.app.models.base import Base, TimestampMixin
from backend.app.models.child import (
    Child,
    ChildStatus,
    Parent,
    ParentStatus,
)
from backend.app.models.report import (
    ActivityCategory,
    ActivityEntry,
    DailyReport,
    DailyReportStatus,
    VoiceRecord,
    VoiceRecordStatus,
)
from backend.app.models.user import (
    Class_,
    School,
    SchoolStatus,
    Teacher,
    TeacherStatus,
)

__all__ = [
    "ActivityCategory",
    "ActivityEntry",
    "Base",
    "Child",
    "ChildStatus",
    "Class_",
    "DailyReport",
    "DailyReportStatus",
    "Parent",
    "ParentStatus",
    "School",
    "SchoolStatus",
    "Teacher",
    "TeacherStatus",
    "TimestampMixin",
    "VoiceRecord",
    "VoiceRecordStatus",
]
