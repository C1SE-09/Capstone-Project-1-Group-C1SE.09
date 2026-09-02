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
from app.models.user import (
    Class_,
    School,
    SchoolStatus,
    Teacher,
    TeacherStatus,
)
from app.models.child import (
    Child,
    ChildStatus,
    Parent,
    ParentStatus,
)
from app.models.report import (
    ActivityCategory,
    ActivityEntry,
    DailyReport,
    DailyReportStatus,
    VoiceRecord,
    VoiceRecordStatus,
)

__all__ = [
    # Base
    "Base",
    "TimestampMixin",
    # School
    "School",
    "SchoolStatus",
    # Class
    "Class_",
    # Teacher
    "Teacher",
    "TeacherStatus",
    # Child & Parent (TASK-1.2.2)
    "Child",
    "ChildStatus",
    "Parent",
    "ParentStatus",
    # Voice & Daily Report (TASK-1.2.3)
    "VoiceRecord",
    "VoiceRecordStatus",
    "DailyReport",
    "DailyReportStatus",
    "ActivityEntry",
    "ActivityCategory",
]

