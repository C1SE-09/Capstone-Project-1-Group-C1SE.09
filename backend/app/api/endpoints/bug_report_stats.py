"""
app/api/endpoints/bug_reports.py (thêm /stats)
============================================
Thống kê bug reports cho admin dashboard.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from app.core.admin_security import get_current_admin
from app.core.database import get_db
from app.models.admin_user import AdminUser
from app.models.bug_report import BugCategory, BugReport, BugSeverity, BugStatus
from app.models.user import User
from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Tạo 1 router riêng cho stats, sẽ merge vào bug_reports router
stats_router = APIRouter(prefix="/api/bug-reports", tags=["bug-reports"])


@stats_router.get(
    "/stats",
    summary="[Web Admin] Get bug report statistics",
    description=(
        "Trả về thống kê tổng quan cho dashboard: "
        "tổng số reports, phân bố theo status / severity / category, "
        "số reports mới trong 7 ngày qua, số critical chưa xử lý."
    ),
)
def get_bug_report_stats(
    current_admin: AdminUser = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> dict:
    """Dashboard stats cho web admin."""
    # Tổng số reports
    total = db.query(func.count(BugReport.bug_report_id)).scalar() or 0

    # Theo status
    by_status_rows = (
        db.query(BugReport.status, func.count(BugReport.bug_report_id))
        .group_by(BugReport.status)
        .all()
    )
    by_status: dict[str, int] = {s.value: 0 for s in BugStatus}
    for status, count in by_status_rows:
        by_status[status.value] = count

    # Theo severity
    by_severity_rows = (
        db.query(BugReport.severity, func.count(BugReport.bug_report_id))
        .group_by(BugReport.severity)
        .all()
    )
    by_severity: dict[str, int] = {s.value: 0 for s in BugSeverity}
    for sev, count in by_severity_rows:
        by_severity[sev.value] = count

    # Theo category
    by_category_rows = (
        db.query(BugReport.category, func.count(BugReport.bug_report_id))
        .group_by(BugReport.category)
        .all()
    )
    by_category: dict[str, int] = {c.value: 0 for c in BugCategory}
    for cat, count in by_category_rows:
        by_category[cat.value] = count

    # Số reports mới trong 7 ngày qua
    seven_days_ago = datetime.now(UTC) - timedelta(days=7)
    new_last_7_days = (
        db.query(func.count(BugReport.bug_report_id))
        .filter(BugReport.created_at >= seven_days_ago)
        .scalar()
        or 0
    )

    # Số critical chưa xử lý (status = open hoặc in_progress)
    critical_open = (
        db.query(func.count(BugReport.bug_report_id))
        .filter(
            BugReport.severity == BugSeverity.CRITICAL,
            BugReport.status.in_([BugStatus.OPEN, BugStatus.IN_PROGRESS]),
        )
        .scalar()
        or 0
    )

    # Theo role của user gửi
    by_user_role_rows = (
        db.query(User.role, func.count(BugReport.bug_report_id))
        .join(BugReport, BugReport.user_id == User.user_id)
        .group_by(User.role)
        .all()
    )
    by_user_role: dict[str, int] = {r.value: 0 for r in []}  # placeholder
    for role, count in by_user_role_rows:
        by_user_role[role.value if hasattr(role, "value") else str(role)] = count

    return {
        "total": total,
        "by_status": by_status,
        "by_severity": by_severity,
        "by_category": by_category,
        "by_user_role": by_user_role,
        "new_last_7_days": new_last_7_days,
        "critical_open": critical_open,
        "generated_at": datetime.now(UTC).isoformat(),
    }
