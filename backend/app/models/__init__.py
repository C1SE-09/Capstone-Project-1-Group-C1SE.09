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

from app.models.admin_user import AdminUser
from app.models.base import Base, TimestampMixin
from app.models.attendance import AttendanceRecord, AttendanceStatus
from app.models.leave_request import LeaveRequest, LeaveRequestStatus
from app.models.bug_report import (
    BugCategory,
    BugReport,
    BugReportAttachment,
    BugReportHistory,
    BugSeverity,
    BugStatus,
)
from app.models.child import (
    Child,
    ChildStatus,
    Parent,
    ParentChild,
    ParentStatus,
)
from app.models.health_examination import HealthCategory, HealthExamination
from app.models.device_token import DeviceToken
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
from app.models.schedule import (
    ClassSchedule,
    Room,
    Subject,
    TimeSlot,
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
    "AdminUser",
    "Base",
    "BroadcastReportStatus",
    "BugCategory",
    "BugReport",
    "BugReportAttachment",
    "BugReportHistory",
    "BugSeverity",
    "BugStatus",
    "Child",
    "ChildStatus",
    "ClassBroadcastReport",
    "ClassSchedule",
    "Class_",
    "DailyReport",
    "DailyReportStatus",
    "DailyReportType",
    "DeviceToken",
    "Parent",
    "ParentChild",
    "ParentStatus",
    "Room",
    "School",
    "SchoolStatus",
    "Subject",
    "Teacher",
    "TeacherStatus",
    "TimeSlot",
    "TimestampMixin",
    "User",
    "UserRole",
    "UserStatus",
    "VoiceRecord",
    "VoiceRecordScope",
    "VoiceRecordStatus",
    "AttendanceRecord",
    "AttendanceStatus",
    "HealthCategory",
    "HealthExamination",
    "LeaveRequest",
    "LeaveRequestStatus",
]
