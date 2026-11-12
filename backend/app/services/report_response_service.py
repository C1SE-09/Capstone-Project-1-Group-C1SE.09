"""
app/services/report_response_service.py
=======================================
Business logic cho "Phản hồi báo cáo" (parent/teacher replies under a report).

Tách khỏi endpoint để:
- Phân quyền tập trung 1 chỗ (dùng lại ``app.core.access.resolve_child_for_actor``).
- Test được bằng pytest mà không cần TestClient.
- Tránh lặp logic "report phải đã SENT mới được phản hồi".

Quy ước nghiệp vụ
-----------------
* Chỉ phản hồi được trên báo cáo đã **gửi** cho phụ huynh
  (status SENT / READ / PUBLISHED). Báo cáo DRAFT thì chưa tới phụ huynh.
* Danh sách phản hồi **phẳng**, sắp xếp theo ``created_at`` tăng dần.
* ``is_read`` chỉ có ý nghĩa với phản hồi của phụ huynh (giáo viên đọc).
  Khi giáo viên mở danh sách → đánh dấu tất cả phản hồi của phụ huynh là đã đọc.
* ``is_resolved`` do giáo viên (hoặc admin) bấm "Đã xử lý".
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import role_of
from app.models.child import Child
from app.models.report import DailyReport, DailyReportStatus
from app.models.report_response import ReportResponse, ResponseAuthorRole
from app.models.user import User

#: Các trạng thái báo cáo mà phụ huynh đã nhận được → được phản hồi.
RESPONSIBLE_REPORT_STATUSES = (
    DailyReportStatus.SENT,
    DailyReportStatus.READ,
    DailyReportStatus.PUBLISHED,
)

#: Chiều dài tối đa nội dung phản hồi (ký tự).
MAX_CONTENT_LENGTH = 2000


# ===========================================================================
# Helpers
# ===========================================================================


def _author_name(response: ReportResponse) -> str:
    """Tên hiển thị của người viết phản hồi.

    Ưu tiên tên thật từ profile (Teacher/Parent); fallback sang username.
    """
    author = response.author
    if author is None:
        return "Người dùng đã xoá"
    if author.teacher is not None and author.teacher.full_name:
        return author.teacher.full_name
    if author.parent is not None and author.parent.full_name:
        return author.parent.full_name
    return author.username


def _author_avatar(response: ReportResponse) -> str | None:
    """Ảnh đại diện của người viết phản hồi (nếu có)."""
    author = response.author
    if author is None:
        return None
    if author.teacher is not None and author.teacher.avatar_url:
        return author.teacher.avatar_url
    if author.parent is not None and author.parent.avatar_url:
        return author.parent.avatar_url
    return None


def to_dict(response: ReportResponse) -> dict[str, Any]:
    """Chuyển 1 ReportResponse → dict cho API response."""
    return {
        "response_id": str(response.response_id),
        "daily_report_id": str(response.daily_report_id),
        "child_id": str(response.child_id) if response.child_id else None,
        "author_user_id": (
            str(response.author_user_id) if response.author_user_id else None
        ),
        "author_role": response.author_role,
        "author_name": _author_name(response),
        "author_avatar_url": _author_avatar(response),
        "content": response.content,
        "image_url": response.image_url,
        "has_image": bool(response.image_url),
        "is_read": response.is_read,
        "is_resolved": response.is_resolved,
        "resolved_at": (
            response.resolved_at.isoformat() if response.resolved_at else None
        ),
        "created_at": response.created_at.isoformat() if response.created_at else None,
        "updated_at": response.updated_at.isoformat() if response.updated_at else None,
    }


# ===========================================================================
# Query helpers
# ===========================================================================


def get_report(db: Session, report_id: uuid.UUID) -> DailyReport:
    """Lấy báo cáo hoặc 404."""
    report = (
        db.query(DailyReport)
        .filter(DailyReport.daily_report_id == report_id)
        .first()
    )
    if report is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy báo cáo")
    return report


def ensure_report_responsed(db: Session, report_id: uuid.UUID) -> DailyReport:
    """Đảm bảo báo cáo đã gửi tới phụ huynh → mới cho phản hồi."""
    report = get_report(db, report_id)
    if report.status not in RESPONSIBLE_REPORT_STATUSES:
        raise HTTPException(
            status_code=409,
            detail="Chỉ có thể phản hồi khi báo cáo đã được gửi cho phụ huynh",
        )
    return report


def list_responses(db: Session, report_id: uuid.UUID) -> list[ReportResponse]:
    """Danh sách phản hồi của 1 báo cáo, phẳng, cũ → mới."""
    return (
        db.query(ReportResponse)
        .filter(ReportResponse.daily_report_id == report_id)
        .order_by(ReportResponse.created_at.asc(), ReportResponse.response_id.asc())
        .all()
    )


def count_unread_from_parent(db: Session, report_id: uuid.UUID) -> int:
    """Số phản hồi của phụ huynh chưa được giáo viên đọc."""
    return (
        db.query(ReportResponse)
        .filter(
            ReportResponse.daily_report_id == report_id,
            ReportResponse.author_role == ResponseAuthorRole.PARENT.value,
            ReportResponse.is_read.is_(False),
        )
        .count()
    )


def mark_all_read(
    db: Session,
    report_id: uuid.UUID,
    reader_user_id: uuid.UUID | None = None,
    reader_role: str | None = None,
) -> int:
    """Đánh dấu đã đọc các phản hồi chưa đọc trong báo cáo.

    - Nếu có reader_user_id: đánh dấu tin do người khác gửi (author_user_id != reader_user_id).
    - Nếu reader_role là teacher/admin: đánh dấu tin của phụ huynh.
    - Nếu reader_role là parent: đánh dấu tin của giáo viên.
    """
    query = db.query(ReportResponse).filter(
        ReportResponse.daily_report_id == report_id,
        ReportResponse.is_read.is_(False),
    )
    if reader_user_id is not None:
        query = query.filter(ReportResponse.author_user_id != reader_user_id)
    elif reader_role in {"teacher", "admin"}:
        query = query.filter(ReportResponse.author_role == ResponseAuthorRole.PARENT.value)
    elif reader_role == "parent":
        query = query.filter(ReportResponse.author_role != ResponseAuthorRole.PARENT.value)
    else:
        query = query.filter(ReportResponse.author_role == ResponseAuthorRole.PARENT.value)

    unread = query.all()
    for row in unread:
        row.is_read = True
    if unread:
        db.commit()
    return len(unread)


# ===========================================================================
# Mutating operations
# ===========================================================================


def create_response(
    db: Session,
    *,
    report: DailyReport,
    author: User,
    content: str,
    image_url: str | None = None,
    author_role: str | None = None,
) -> ReportResponse:
    """Tạo 1 phản hồi mới dưới báo cáo.

    Args:
        db: session
        report: báo cáo cha (đã kiểm tra qua ``ensure_report_responsed``)
        author: user đang đăng nhập
        content: nội dung (đã strip)
        image_url: đường dẫn ảnh private (nếu có)
        author_role: snapshot vai trò; mặc định lấy từ ``author.role``

    Raises:
        HTTPException 422 nếu nội dung rỗng hoặc quá dài.
    """
    text = (content or "").strip()
    if not text:
        raise HTTPException(status_code=422, detail="Nội dung phản hồi không được để trống")
    if len(text) > MAX_CONTENT_LENGTH:
        raise HTTPException(
            status_code=422,
            detail=f"Nội dung phản hồi không được vượt quá {MAX_CONTENT_LENGTH} ký tự",
        )

    resolved_role = author_role or role_of(author)
    if resolved_role not in {r.value for r in ResponseAuthorRole}:
        resolved_role = ResponseAuthorRole.PARENT.value

    response = ReportResponse(
        daily_report_id=report.daily_report_id,
        child_id=report.child_id,
        author_user_id=author.user_id,
        author_role=resolved_role,
        content=text,
        image_url=image_url,
        is_read=False,
        is_resolved=False,
    )
    db.add(response)
    db.commit()
    db.refresh(response)
    return response


def set_resolved(
    db: Session,
    *,
    response: ReportResponse,
    actor: User,
    resolved: bool,
) -> ReportResponse:
    """Đánh dấu (huỷ) phản hồi đã xử lý."""
    response.is_resolved = resolved
    response.resolved_at = datetime.now(UTC) if resolved else None
    response.resolved_by_user_id = actor.user_id if resolved else None
    db.commit()
    db.refresh(response)
    return response


def delete_response(db: Session, response: ReportResponse) -> None:
    """Xoá 1 phản hồi (dùng khi báo cáo bị xoá hoặc cần dọn dẹp)."""
    db.delete(response)
    db.commit()


def child_of_report(db: Session, report: DailyReport) -> Child | None:
    """Lấy hồ sơ bé của báo cáo (nếu còn tồn tại)."""
    if report.child_id is None:
        return None
    return db.query(Child).filter(Child.child_id == report.child_id).first()
