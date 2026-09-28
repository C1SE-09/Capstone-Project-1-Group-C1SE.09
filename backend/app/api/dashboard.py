"""
app/api/dashboard.py
====================
API endpoints tổng hợp dữ liệu cho các màn Tổng quan (Teacher + Parent),
Chi tiết lớp và Báo cáo lớp của Flutter client.

Các endpoint này trả JSON với key snake_case, khớp đúng contract mà
`HttpDashboardRepository` (frontend) parse bằng `*.fromJson`.

MVP Note:
    Auth bị bỏ qua — id (teacher_id / parent_id) được nhận trực tiếp từ path.
    TODO (sprint 2): Thay bằng Firebase JWT middleware.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.child import Child, ChildStatus, Parent
from app.models.report import DailyReport, DailyReportStatus, VoiceRecord
from app.models.user import Class_, Teacher

router = APIRouter(tags=["dashboard"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _class_info_dict(class_: Class_) -> dict[str, Any]:
    """Chuyển 1 Class_ → dict khớp entity ClassInfo (frontend)."""
    return {
        "class_id": str(class_.class_id),
        "school_id": str(class_.school_id),
        "name": class_.name,
        "grade_label": class_.grade_label,
        "room_number": class_.room_number,
        "capacity": class_.capacity,
        "is_active": class_.is_active,
    }


def _teacher_dict(teacher: Teacher) -> dict[str, Any]:
    """Chuyển 1 Teacher → dict khớp entity Teacher (frontend)."""
    return {
        "teacher_id": str(teacher.teacher_id),
        "school_id": str(teacher.school_id),
        "class_id": str(teacher.class_id) if teacher.class_id else None,
        "full_name": teacher.full_name,
        "email": teacher.email,
        "phone": teacher.phone,
        "avatar_url": teacher.avatar_url,
        "is_verified": teacher.is_verified,
    }


def _child_dict(child: Child) -> dict[str, Any]:
    """Chuyển 1 Child → dict khớp entity Child (frontend)."""
    return {
        "child_id": str(child.child_id),
        "parent_id": str(child.parent_id) if child.parent_id else None,
        "class_id": str(child.class_id) if child.class_id else None,
        "full_name": child.full_name,
        "nickname": child.nickname,
        "date_of_birth": (
            child.date_of_birth.isoformat() if child.date_of_birth else None
        ),
        "gender": child.gender,
        "avatar_url": child.avatar_url,
        "medical_allergies": child.medical_allergies,
    }


def _report_dict(report: DailyReport) -> dict[str, Any]:
    """Chuyển 1 DailyReport → dict khớp entity DailyReport (frontend)."""
    return {
        "daily_report_id": str(report.daily_report_id),
        "teacher_id": str(report.teacher_id) if report.teacher_id else None,
        "child_id": str(report.child_id) if report.child_id else None,
        "voice_record_id": (
            str(report.voice_record_id) if report.voice_record_id else None
        ),
        "report_date": report.report_date.isoformat(),
        "summary_text": report.summary_text,
        "status": report.status.value,
        "published_at": (
            report.published_at.isoformat() if report.published_at else None
        ),
    }


# ---------------------------------------------------------------------------
# Teacher
# ---------------------------------------------------------------------------


@router.get("/api/teacher/{teacher_id}", summary="Thông tin giáo viên")
def get_teacher(
    teacher_id: uuid.UUID,
    db: Session = Depends(get_db),  # noqa: B008
):
    """Trả về thông tin 1 giáo viên (cho màn Tổng quan)."""
    teacher = (
        db.query(Teacher).filter(Teacher.teacher_id == teacher_id).first()
    )
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    return _teacher_dict(teacher)


@router.get(
    "/api/teacher/{teacher_id}/classes",
    summary="Danh sách lớp giáo viên phụ trách + summary báo cáo",
)
def get_teacher_classes(
    teacher_id: uuid.UUID,
    db: Session = Depends(get_db),  # noqa: B008
):
    """
    Trả về danh sách lớp của giáo viên kèm summary báo cáo hôm nay,
    khớp entity ClassReportOverview ở frontend.
    """
    teacher = (
        db.query(Teacher).filter(Teacher.teacher_id == teacher_id).first()
    )
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")

    # Lớp chủ nhiệm (class_id) — MVP 1 giáo viên 1 lớp.
    # Nếu class_id NULL thì trả rỗng.
    class_ids: list[Any] = []
    if teacher.class_id is not None:
        class_ids.append(teacher.class_id)

    result: list[dict[str, Any]] = []
    for cid in class_ids:
        class_ = db.query(Class_).filter(Class_.class_id == cid).first()
        if class_ is None:
            continue

        children = (
            db.query(Child)
            .filter(
                Child.class_id == cid,
                Child.status == ChildStatus.ENROLLED,
            )
            .all()
        )
        total = len(children)
        child_ids = [c.child_id for c in children]

        # Thống kê báo cáo hôm nay
        today = datetime.now(tz=timezone.utc).date()
        reports = (
            db.query(DailyReport)
            .filter(
                DailyReport.child_id.in_(child_ids),
                DailyReport.report_date == today,
            )
            .all()
        )
        by_child: dict[Any, DailyReport] = {
            r.child_id: r for r in reports if r.child_id is not None
        }

        completed = sum(
            1
            for c in child_ids
            if c in by_child
            and by_child[c].status == DailyReportStatus.PUBLISHED
        )
        draft = sum(
            1
            for c in child_ids
            if c in by_child
            and by_child[c].status == DailyReportStatus.DRAFT
        )
        missing = total - completed - draft

        result.append(
            {
                "class_info": _class_info_dict(class_),
                "teacher_name": teacher.full_name,
                "total_children": total,
                "completed_count": completed,
                "draft_count": draft,
                "missing_count": missing,
            }
        )

    return {"classes": result}


# ---------------------------------------------------------------------------
# Class dashboard & activities
# ---------------------------------------------------------------------------


@router.get(
    "/api/class/{class_id}/dashboard",
    summary="Tổng hợp báo cáo lớp trong 1 ngày",
)
def get_class_dashboard(
    class_id: uuid.UUID,
    date_param: date | None = Query(default=None, alias="date"),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
):
    """
    Trả về summary của lớp khớp ClassDashboardSummary (frontend):
    tổng trẻ, completed/draft/missing, danh sách trẻ cần xử lý.
    """
    class_ = db.query(Class_).filter(Class_.class_id == class_id).first()
    if class_ is None:
        raise HTTPException(status_code=404, detail="Class not found")

    target_date = date_param or datetime.now(tz=timezone.utc).date()

    children = (
        db.query(Child)
        .filter(Child.class_id == class_id, Child.status == ChildStatus.ENROLLED)
        .order_by(Child.full_name)
        .all()
    )
    total = len(children)
    child_ids = [c.child_id for c in children]

    reports = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id.in_(child_ids),
            DailyReport.report_date == target_date,
        )
        .all()
    )
    by_child: dict[Any, DailyReport] = {
        r.child_id: r for r in reports if r.child_id is not None
    }

    completed = 0
    draft = 0

    pending: list[dict[str, Any]] = []
    for child in children:
        report = by_child.get(child.child_id)
        if report is None:
            # chưa có báo cáo → "Chưa có"
            pending.append(
                {"child": _child_dict(child), "status": None, "updated_at": None}
            )
        elif report.status in (DailyReportStatus.PUBLISHED, DailyReportStatus.SENT):
            completed += 1
            pending.append(
                {
                    "child": _child_dict(child),
                    "status": "published",
                    "updated_at": None,
                }
            )
        elif report.status == DailyReportStatus.DRAFT:
            draft += 1
            pending.append(
                {
                    "child": _child_dict(child),
                    "status": "draft",
                    "updated_at": None,
                }
            )

    missing = total - completed - draft

    # Tên giáo viên chủ nhiệm (nếu có)
    teacher = (
        db.query(Teacher).filter(Teacher.class_id == class_id).first()
    )
    teacher_name = teacher.full_name if teacher else ""

    return {
        "class_info": _class_info_dict(class_),
        "teacher_name": teacher_name,
        "total_children": total,
        "completed_count": completed,
        "draft_count": draft,
        "missing_count": missing,
        "pending_children": pending,
    }


@router.get(
    "/api/class/{class_id}/activities",
    summary="Hoạt động gần đây của lớp (timeline)",
)
def get_class_activities(
    class_id: uuid.UUID,
    limit: int = Query(default=10, ge=1, le=50),
    db: Session = Depends(get_db),  # noqa: B008
):
    """
    Trả về timeline hoạt động gần đây, khớp ActivityItem (frontend).
    Nguồn: DailyReport (đã gửi/review) + VoiceRecord (đã ghi âm).
    """
    class_ = db.query(Class_).filter(Class_.class_id == class_id).first()
    if class_ is None:
        raise HTTPException(status_code=404, detail="Class not found")

    child_ids = [
        c.child_id
        for c in db.query(Child)
        .filter(Child.class_id == class_id, Child.status == ChildStatus.ENROLLED)
        .all()
    ]

    activities: list[dict[str, Any]] = []

    # 1) Báo cáo đã PUBLISHED / SENT / READ
    published = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id.in_(child_ids),
            DailyReport.status.in_([
                DailyReportStatus.PUBLISHED,
                DailyReportStatus.SENT,
                DailyReportStatus.READ,
            ]),
        )
        .order_by(DailyReport.created_at.desc())
        .limit(limit)
        .all()
    )
    for r in published:
        child_name = r.child.full_name if r.child else "trẻ"
        activities.append(
            {
                "type": "reportSent",
                "message": f"Báo cáo của {child_name} đã được gửi",
                "occurred_at": (
                    r.created_at.isoformat() if r.created_at else r.report_date.isoformat()
                ),
            }
        )

    # 2) Báo cáo DRAFT (đang chờ xem lại)
    drafts = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id.in_(child_ids),
            DailyReport.status == DailyReportStatus.DRAFT,
        )
        .order_by(DailyReport.created_at.desc())
        .limit(limit)
        .all()
    )
    for r in drafts:
        child_name = r.child.full_name if r.child else "trẻ"
        activities.append(
            {
                "type": "reportReviewing",
                "message": f"Báo cáo của {child_name} đang chờ xem lại",
                "occurred_at": (
                    r.created_at.isoformat() if r.created_at else r.report_date.isoformat()
                ),
            }
        )

    # 3) Ghi âm gần đây
    records = (
        db.query(VoiceRecord)
        .filter(VoiceRecord.child_id.in_(child_ids))
        .order_by(VoiceRecord.created_at.desc())
        .limit(limit)
        .all()
    )
    for v in records:
        child_name = v.child.full_name if v.child else "trẻ"
        activities.append(
            {
                "type": "audioRecorded",
                "message": f"Đã ghi âm cho {child_name}",
                "occurred_at": (
                    v.created_at.isoformat() if v.created_at else None
                ),
            }
        )

    # Sắp xếp theo thời gian giảm dần, giới hạn `limit`
    def _sort_key(a: dict[str, Any]) -> str:
        return a.get("occurred_at") or ""

    activities.sort(key=_sort_key, reverse=True)
    return {"activities": activities[:limit]}


# ---------------------------------------------------------------------------
# Parent
# ---------------------------------------------------------------------------


@router.get("/api/parent/{parent_id}", summary="Thông tin phụ huynh")
def get_parent(
    parent_id: uuid.UUID,
    db: Session = Depends(get_db),  # noqa: B008
):
    """Trả về thông tin 1 phụ huynh, khớp entity Parent (frontend)."""
    parent = db.query(Parent).filter(Parent.parent_id == parent_id).first()
    if not parent:
        raise HTTPException(status_code=404, detail="Parent not found")
    return {
        "parent_id": str(parent.parent_id),
        "full_name": parent.full_name,
        "phone": parent.phone,
        "email": parent.email,
        "avatar_url": parent.avatar_url,
        "is_verified": parent.is_verified,
    }


@router.get(
    "/api/parent/{parent_id}/child",
    summary="Con (duy nhất trong MVP) + lớp + giáo viên",
)
def get_parent_primary_child(
    parent_id: uuid.UUID,
    db: Session = Depends(get_db),  # noqa: B008
):
    """
    Trả về 1 đứa con (đầu tiên) + tên lớp + tên giáo viên,
    khớp entity ChildOverview (frontend).
    """
    parent = db.query(Parent).filter(Parent.parent_id == parent_id).first()
    if not parent:
        raise HTTPException(status_code=404, detail="Parent not found")

    children = (
        db.query(Child)
        .filter(
            Child.parent_id == parent_id,
            Child.status == ChildStatus.ENROLLED,
        )
        .order_by(Child.full_name)
        .all()
    )

    if not children:
        raise HTTPException(status_code=404, detail="Child not found")

    child = children[0]
    class_name = ""
    teacher_name = ""
    if child.class_id:
        class_ = (
            db.query(Class_).filter(Class_.class_id == child.class_id).first()
        )
        if class_:
            class_name = class_.name
            teacher = (
                db.query(Teacher)
                .filter(Teacher.class_id == class_.class_id)
                .first()
            )
            teacher_name = teacher.full_name if teacher else ""

    return {
        "child": _child_dict(child),
        "class_name": class_name,
        "teacher_name": teacher_name,
    }


# ---------------------------------------------------------------------------
# Child reports
# ---------------------------------------------------------------------------


@router.get(
    "/api/child/{child_id}/reports",
    summary="Báo cáo của trẻ: hôm nay + gần đây",
)
def get_child_reports(
    child_id: uuid.UUID,
    date_param: date | None = Query(default=None, alias="date"),  # noqa: B008
    limit: int = Query(default=7, ge=1, le=50),
    db: Session = Depends(get_db),  # noqa: B008
):
    """
    Trả về báo cáo hôm nay (riêng) + danh sách gần đây (mới nhất trước),
    khớp nhu cầu của ParentHomeController.
    """
    child = db.query(Child).filter(Child.child_id == child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")

    target_date = date_param or datetime.now(tz=timezone.utc).date()

    today_report = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id == child_id,
            DailyReport.report_date == target_date,
        )
        .order_by(DailyReport.created_at.desc())
        .first()
    )

    recent = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id == child_id,
            DailyReport.status.in_([
                DailyReportStatus.PUBLISHED,
                DailyReportStatus.SENT,
                DailyReportStatus.READ,
            ]),
        )
        .order_by(DailyReport.report_date.desc())
        .limit(limit)
        .all()
    )

    return {
        "today_report": _report_dict(today_report) if today_report else None,
        "recent_reports": [_report_dict(r) for r in recent],
    }