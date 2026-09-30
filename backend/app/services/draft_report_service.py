"""
app/services/draft_report_service.py
=====================================
Service để tạo/upsert draft DailyReport từ extraction_result.

Dùng cho flow Auto-detect (Task #57 extension):
- User bấm "Duyệt" trên 1 item → tạo draft NGAY
- 3 loại item:
  - "classwide": tạo N drafts (1 cho mỗi child trong class)
  - "child": tạo/update 1 draft cho child đó
  - "unmatched": không tạo draft (user phải gán cho child trước)

Quy tắc merge content:
  final_X = child_override.X ?? class_wide.X ?? None

Upsert logic:
  Dùng UniqueConstraint(child_id, report_date) để 1 bé chỉ có tối đa 1 draft / ngày.
  Nếu đã có → update, nếu chưa → insert.

Quan trọng:
  - KHÔNG dùng ClassBroadcastReport (giữ tương thích nhưng không tạo mới)
  - Class-wide content LUÔN là default template
  - Child override REPLACE các field class-wide
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from app.models.child import Child
from app.models.report import (
    ActivityCategory,
    ActivityEntry,
    DailyReport,
    DailyReportStatus,
    VoiceRecord,
)
from app.models.user import Class_
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


# ===========================================================================
# Constants
# ===========================================================================

# 5 fields chính được trích xuất
FIELDS_MAPPING: list[tuple[str, str, str]] = [
    ("meals", "MEAL", "Bữa ăn"),
    ("sleeping", "NAP", "Giấc ngủ"),
    ("health", "HEALTH", "Sức khỏe"),
    ("activities", "PLAY", "Hoạt động"),
    ("mood", "BEHAVIOR", "Tâm trạng"),
]


# ===========================================================================
# Helpers
# ===========================================================================

def _merge_extraction(
    class_wide: dict[str, str | None] | None,
    child_override: dict[str, str | None] | None,
) -> dict[str, str | None]:
    """
    Merge class-wide default + child override.

    Logic:
        final_X = child_override[X] ?? class_wide[X] ?? None

    Args:
        class_wide: Content cho cả lớp (None nếu không có)
        child_override: Content riêng cho child (None nếu không có)

    Returns:
        dict[meals, sleeping, health, activities, mood]
    """
    class_wide = class_wide or {}
    child_override = child_override or {}

    merged = {}
    for key, _, _ in FIELDS_MAPPING:
        # Child override wins; fallback to class-wide
        merged[key] = child_override.get(key) or class_wide.get(key)
    return merged


def _get_or_create_draft(
    db: Session,
    child_id: uuid.UUID,
    teacher_id: uuid.UUID,
    voice_record_id: uuid.UUID,
    report_date: datetime,
) -> DailyReport:
    """
    Lấy draft hiện tại hoặc tạo mới (upsert dựa trên unique constraint).

    Returns:
        DailyReport (existing or newly created)
    """
    report = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id == child_id,
            DailyReport.report_date == report_date,
        )
        .first()
    )

    if report:
        # Update: ghi đè voice_record_id (có thể đã tạo từ voice_record khác)
        report.voice_record_id = voice_record_id
        report.teacher_id = teacher_id
        # Xóa ActivityEntry cũ để ghi lại
        db.query(ActivityEntry).filter(
            ActivityEntry.daily_report_id == report.daily_report_id
        ).delete()
        logger.info(
            "[draft_report_service] Updating existing draft: report_id=%s child_id=%s",
            report.daily_report_id, child_id,
        )
    else:
        report = DailyReport(
            child_id=child_id,
            teacher_id=teacher_id,
            voice_record_id=voice_record_id,
            report_date=report_date,
            status=DailyReportStatus.DRAFT,
        )
        db.add(report)
        db.flush()  # Lấy daily_report_id
        logger.info(
            "[draft_report_service] Creating new draft: report_id=%s child_id=%s",
            report.daily_report_id, child_id,
        )

    return report


def _populate_activities(
    db: Session,
    report: DailyReport,
    extraction: dict[str, str | None],
) -> list[ActivityEntry]:
    """
    Tạo ActivityEntry rows từ extraction dict (sau khi merge).

    Chỉ tạo entry khi value != None và không empty.
    """
    entries = []
    order = 0
    for key, category_str, title in FIELDS_MAPPING:
        value = extraction.get(key)
        if value and value.strip():
            entry = ActivityEntry(
                daily_report_id=report.daily_report_id,
                category=ActivityCategory[category_str],
                title=title,
                description=value.strip(),
                entry_order=order,
            )
            db.add(entry)
            entries.append(entry)
            order += 1

    return entries


def _today_utc() -> datetime:
    """Lấy ngày hiện tại theo UTC (chỉ date part)."""
    return datetime.now(timezone.utc).date()


# ===========================================================================
# Public API - 3 functions chính
# ===========================================================================


def create_classwide_drafts(
    db: Session,
    class_id: uuid.UUID,
    voice_record_id: uuid.UUID,
    teacher_id: uuid.UUID,
    class_wide_extraction: dict[str, str | None] | None = None,
    child_overrides: dict[str, dict[str, str | None]] | None = None,
    report_date: datetime | None = None,
) -> dict[str, Any]:
    """
    Tạo drafts cho TẤT CẢ children trong class.

    Args:
        db: SQLAlchemy session
        class_id: UUID của lớp
        voice_record_id: UUID của VoiceRecord nguồn
        teacher_id: UUID của giáo viên
        class_wide_extraction: Content mặc định cho cả lớp (None nếu không có)
        child_overrides: dict[child_id → override extraction]
                         Bé không có trong dict này → chỉ dùng class-wide default
        report_date: Ngày của report (mặc định = hôm nay UTC)

    Returns:
        {
            "draft_report_ids": [uuid, ...],
            "count": N,
            "child_id_to_report_id": {child_id: report_id, ...}
        }

    Raises:
        ValueError: Nếu class_id không tồn tại hoặc không có children
    """
    # Validate class
    cls = db.query(Class_).filter(Class_.class_id == class_id).first()
    if not cls:
        raise ValueError(f"Class {class_id} not found")

    # Get children trong lớp
    children = db.query(Child).filter(Child.class_id == class_id).all()
    if not children:
        raise ValueError(f"Class {class_id} has no children")

    # Validate voice_record
    voice_record = (
        db.query(VoiceRecord)
        .filter(VoiceRecord.voice_record_id == voice_record_id)
        .first()
    )
    if not voice_record:
        raise ValueError(f"VoiceRecord {voice_record_id} not found")

    report_date = report_date or _today_utc()
    child_overrides = child_overrides or {}

    draft_ids: list[uuid.UUID] = []
    child_id_to_report_id: dict[str, str] = {}

    for child in children:
        child_id = str(child.child_id)
        override = child_overrides.get(child_id)

        # Merge: override > class-wide default
        merged = _merge_extraction(class_wide_extraction, override)

        # Get or create draft
        report = _get_or_create_draft(
            db=db,
            child_id=child.child_id,
            teacher_id=teacher_id,
            voice_record_id=voice_record_id,
            report_date=report_date,
        )

        # Tạo ActivityEntry từ merged content
        _populate_activities(db, report, merged)

        draft_ids.append(report.daily_report_id)
        child_id_to_report_id[child_id] = str(report.daily_report_id)

    db.commit()
    logger.info(
        "[draft_report_service] create_classwide_drafts: class_id=%s count=%d",
        class_id, len(draft_ids),
    )

    return {
        "draft_report_ids": draft_ids,
        "count": len(draft_ids),
        "child_id_to_report_id": child_id_to_report_id,
    }


def create_child_draft(
    db: Session,
    child_id: uuid.UUID,
    voice_record_id: uuid.UUID,
    teacher_id: uuid.UUID,
    class_wide_extraction: dict[str, str | None] | None = None,
    child_override: dict[str, str | None] | None = None,
    report_date: datetime | None = None,
) -> dict[str, Any]:
    """
    Tạo draft cho 1 child cụ thể (với override content).

    Args:
        db: SQLAlchemy session
        child_id: UUID của child
        voice_record_id: UUID của VoiceRecord nguồn
        teacher_id: UUID của giáo viên
        class_wide_extraction: Default content cho cả lớp (optional)
        child_override: Override content cho child này (optional)
        report_date: Ngày của report (mặc định = hôm nay UTC)

    Returns:
        {
            "draft_report_id": uuid,
            "child_id": uuid,
            "merged_extraction": {meals, sleeping, health, activities, mood}
        }

    Raises:
        ValueError: Nếu child_id hoặc voice_record_id không tồn tại
    """
    child = db.query(Child).filter(Child.child_id == child_id).first()
    if not child:
        raise ValueError(f"Child {child_id} not found")

    voice_record = (
        db.query(VoiceRecord)
        .filter(VoiceRecord.voice_record_id == voice_record_id)
        .first()
    )
    if not voice_record:
        raise ValueError(f"VoiceRecord {voice_record_id} not found")

    report_date = report_date or _today_utc()

    # Merge content
    merged = _merge_extraction(class_wide_extraction, child_override)

    # Get or create draft
    report = _get_or_create_draft(
        db=db,
        child_id=child_id,
        teacher_id=teacher_id,
        voice_record_id=voice_record_id,
        report_date=report_date,
    )

    # Populate activities
    _populate_activities(db, report, merged)

    db.commit()
    logger.info(
        "[draft_report_service] create_child_draft: child_id=%s report_id=%s",
        child_id, report.daily_report_id,
    )

    return {
        "draft_report_id": report.daily_report_id,
        "child_id": child_id,
        "merged_extraction": merged,
    }


def create_unmatched_drafts(
    db: Session,
    class_id: uuid.UUID,
    voice_record_id: uuid.UUID,
    teacher_id: uuid.UUID,
    class_wide_extraction: dict[str, str | None] | None = None,
    report_date: datetime | None = None,
) -> dict[str, Any]:
    """
    Tạo 1 draft "ghost" lưu các unmatched segments.

    Note: Unmatched segments không có child_id, nên không thể tạo DailyReport
    theo cách thông thường. Thay vào đó, chúng được lưu vào voice_record
    extraction_result dưới dạng 'unmatched_segments' đã có sẵn.

    Function này chỉ là placeholder để giữ API symmetry. Hiện tại trả về
    empty result. Nếu sau này cần, có thể tạo 1 DailyReport "chưa rõ bé"
    với child_id = NULL (đã cho phép trong schema).

    Returns:
        {
            "draft_report_id": None,
            "count": 0,
            "note": "Unmatched segments stored in voice_record.extraction_result"
        }
    """
    logger.info(
        "[draft_report_service] create_unmatched_drafts: no-op (kept for API symmetry)"
    )
    return {
        "draft_report_id": None,
        "count": 0,
        "note": "Unmatched segments stored in voice_record.extraction_result",
    }


# ===========================================================================
# Utility: đọc lại extraction đã merge sẵn cho 1 child
# ===========================================================================

def get_merged_extraction_for_child(
    voice_record_extraction: dict[str, Any],
    child_id: uuid.UUID,
) -> dict[str, str | None]:
    """
    Helper: Tính merged extraction cho 1 child (class-wide + override).

    Frontend có thể dùng để preview content trước khi user bấm Duyệt.

    Args:
        voice_record_extraction: Toàn bộ extraction_result từ VoiceRecord
        child_id: UUID của child cần tính

    Returns:
        dict[meals, sleeping, health, activities, mood]
    """
    class_wide = voice_record_extraction.get("class_wide_extraction") or {}
    child_overrides = voice_record_extraction.get("child_extractions") or {}
    override = child_overrides.get(str(child_id)) or {}

    return _merge_extraction(class_wide, override)