from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone

import redis
from app.config import settings
from app.models.child import Child, Parent
from app.models.report import (
    DailyReport,
    DailyReportStatus,
    VoiceRecord,
    VoiceRecordStatus,
)
from app.models.user import Class_, School, Teacher
from app.schemas.admin_dashboard import (
    AdminOverviewStats,
    ClassProgressStat,
    ReportTrendItem,
    SystemHealthStats,
    VoiceRecordStats,
)
from sqlalchemy import Date, cast, func, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

SENT_STATUSES = {
    DailyReportStatus.SENT,
    DailyReportStatus.READ,
    DailyReportStatus.PUBLISHED,
}


def get_overview_stats(db: Session, target_date: date | None = None) -> AdminOverviewStats:
    """Tính toán các chỉ số thống kê tổng quan toàn hệ thống."""
    today = target_date or datetime.now(timezone.utc).date()

    total_schools = db.query(func.count(School.school_id)).scalar() or 0
    total_classes = db.query(func.count(Class_.class_id)).scalar() or 0
    total_children = db.query(func.count(Child.child_id)).scalar() or 0
    total_teachers = db.query(func.count(Teacher.teacher_id)).scalar() or 0
    total_parents = db.query(func.count(Parent.parent_id)).scalar() or 0

    # Báo cáo trong ngày
    today_reports = (
        db.query(DailyReport)
        .filter(DailyReport.report_date == today)
        .all()
    )
    today_reports_count = len(today_reports)
    today_sent_reports_count = sum(1 for r in today_reports if r.status in SENT_STATUSES)
    today_draft_reports_count = sum(1 for r in today_reports if r.status == DailyReportStatus.DRAFT)

    today_completion_rate = (
        round((today_sent_reports_count / total_children) * 100, 2)
        if total_children > 0
        else 0.0
    )

    total_voice_records = db.query(func.count(VoiceRecord.voice_record_id)).scalar() or 0
    today_voice_records = (
        db.query(func.count(VoiceRecord.voice_record_id))
        .filter(cast(VoiceRecord.recorded_at, Date) == today)
        .scalar()
        or 0
    )

    return AdminOverviewStats(
        total_schools=total_schools,
        total_classes=total_classes,
        total_children=total_children,
        total_teachers=total_teachers,
        total_parents=total_parents,
        today_reports_count=today_reports_count,
        today_sent_reports_count=today_sent_reports_count,
        today_draft_reports_count=today_draft_reports_count,
        today_completion_rate=today_completion_rate,
        total_voice_records=total_voice_records,
        today_voice_records=today_voice_records,
    )


def get_classes_progress(db: Session, target_date: date | None = None) -> list[ClassProgressStat]:
    """Lấy danh sách tiến độ nộp báo cáo theo từng lớp trong ngày."""
    today = target_date or datetime.now(timezone.utc).date()
    classes = db.query(Class_).order_by(Class_.name).all()

    results: list[ClassProgressStat] = []

    for c in classes:
        children = db.query(Child.child_id).filter(Child.class_id == c.class_id).all()
        child_ids = [ch[0] for ch in children]
        total_children = len(child_ids)

        reported_count = 0
        if child_ids:
            reports = (
                db.query(DailyReport)
                .filter(DailyReport.report_date == today, DailyReport.child_id.in_(child_ids))
                .all()
            )
            reported_count = sum(1 for r in reports if r.status in SENT_STATUSES)

        pending_count = max(0, total_children - reported_count)
        rate = (
            round((reported_count / total_children) * 100, 2)
            if total_children > 0
            else 0.0
        )

        teacher_name = c.teachers[0].full_name if c.teachers else None

        results.append(
            ClassProgressStat(
                class_id=c.class_id,
                class_name=c.name,
                grade_label=c.grade_label,
                teacher_name=teacher_name,
                total_children=total_children,
                reported_children=reported_count,
                pending_children=pending_count,
                completion_rate=rate,
            )
        )

    return results


def get_report_trends(db: Session, days: int = 7) -> list[ReportTrendItem]:
    """Lấy xu hướng tạo và duyệt báo cáo theo N ngày gần nhất."""
    days = max(1, min(days, 60))
    today = datetime.now(timezone.utc).date()
    start_date = today - timedelta(days=days - 1)

    reports = (
        db.query(DailyReport)
        .filter(DailyReport.report_date >= start_date, DailyReport.report_date <= today)
        .all()
    )

    day_map: dict[str, dict[str, int]] = {}
    for i in range(days):
        d_str = (start_date + timedelta(days=i)).isoformat()
        day_map[d_str] = {"total": 0, "sent": 0, "draft": 0}

    for r in reports:
        d_str = r.report_date.isoformat()
        if d_str in day_map:
            day_map[d_str]["total"] += 1
            if r.status in SENT_STATUSES:
                day_map[d_str]["sent"] += 1
            elif r.status == DailyReportStatus.DRAFT:
                day_map[d_str]["draft"] += 1

    return [
        ReportTrendItem(
            report_date=d_str,
            total_reports=data["total"],
            sent_reports=data["sent"],
            draft_reports=data["draft"],
        )
        for d_str, data in sorted(day_map.items())
    ]


def get_voice_record_stats(db: Session) -> VoiceRecordStats:
    """Thống kê chi tiết tình trạng xử lý các tệp âm thanh STT."""
    total_records = db.query(func.count(VoiceRecord.voice_record_id)).scalar() or 0
    completed_records = (
        db.query(func.count(VoiceRecord.voice_record_id))
        .filter(VoiceRecord.status == VoiceRecordStatus.COMPLETED)
        .scalar()
        or 0
    )
    pending_records = (
        db.query(func.count(VoiceRecord.voice_record_id))
        .filter(
            VoiceRecord.status.in_(
                [VoiceRecordStatus.PENDING, VoiceRecordStatus.PROCESSING]
            )
        )
        .scalar()
        or 0
    )
    failed_records = (
        db.query(func.count(VoiceRecord.voice_record_id))
        .filter(VoiceRecord.status == VoiceRecordStatus.FAILED)
        .scalar()
        or 0
    )
    total_duration = (
        db.query(func.sum(VoiceRecord.audio_duration)).scalar() or 0.0
    )

    return VoiceRecordStats(
        total_records=total_records,
        completed_records=completed_records,
        pending_records=pending_records,
        failed_records=failed_records,
        total_duration_seconds=float(total_duration),
    )


def get_system_health(db: Session) -> SystemHealthStats:
    """Kiểm tra tình trạng hoạt động của PostgreSQL và Redis."""
    # Kiểm tra Database
    db_status = "healthy"
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError as e:
        logger.error(f"Lỗi kiểm tra Database health: {e}")
        db_status = "error"

    # Kiểm tra Redis
    redis_status = "healthy"
    try:
        r = redis.from_url(settings.redis_url, socket_timeout=2)
        r.ping()
    except redis.RedisError as e:
        logger.error(f"Lỗi kiểm tra Redis health: {e}")
        redis_status = "error"

    return SystemHealthStats(
        database_status=db_status,
        redis_status=redis_status,
        api_status="healthy",
        server_time=datetime.now(timezone.utc),
    )
