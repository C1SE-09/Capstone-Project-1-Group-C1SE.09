"""
app/schemas/bug_report.py
=========================
Pydantic schemas for the Bug Report API.

Tách biệt ORM models (``app.models.bug_report``) với API schemas (Pydantic)
theo nguyên tắc Clean Architecture — tránh expose trực tiếp ORM objects
và giữ contract API ổn định khi schema DB thay đổi.

TASK: B-02 – Schemas + service layer
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Annotated, Literal

from app.models.bug_report import BugCategory, BugSeverity, BugStatus
from pydantic import BaseModel, ConfigDict, Field, field_validator


# ===========================================================================
# Re-export Enum values (string-based) cho OpenAPI doc và client
# ===========================================================================


BugCategoryEnum = Literal[
    "ui",
    "performance",
    "crash",
    "data",
    "notification",
    "network",
    "auth",
    "other",
]
"""Category values exposed to clients. Must match ``BugCategory`` enum."""

BugSeverityEnum = Literal["low", "medium", "high", "critical"]
"""Severity values exposed to clients. Must match ``BugSeverity`` enum."""

BugStatusEnum = Literal[
    "open",
    "in_progress",
    "resolved",
    "closed",
    "wont_fix",
]
"""Status values exposed to clients. Must match ``BugStatus`` enum."""


# ===========================================================================
# Helper: convert ORM → Pydantic-friendly dict (defensive)
# ===========================================================================


def _user_summary(user) -> dict | None:
    """Return minimal user info for embedding in bug report responses."""
    if user is None:
        return None
    return {
        "user_id": str(user.user_id),
        "username": user.username,
        "role": user.role.value if hasattr(user.role, "value") else str(user.role),
    }


def _teacher_summary(teacher) -> dict | None:
    """Return minimal teacher info for embedding in bug report responses."""
    if teacher is None:
        return None
    return {
        "teacher_id": str(teacher.teacher_id),
        "full_name": teacher.full_name,
        "email": teacher.email,
    }


# ===========================================================================
# Attachment Schemas
# ===========================================================================


class BugReportAttachmentOut(BaseModel):
    """Một file đính kèm (screenshot, log) của bug report.

    Files được lưu trên MinIO và truy cập qua ``file_url``.
    """

    attachment_id: uuid.UUID = Field(
        ..., description="UUID của attachment"
    )
    file_url: str = Field(..., description="URL đầy đủ đến file trên MinIO")
    file_name: str = Field(..., description="Tên file gốc khi upload")
    file_size: int | None = Field(None, description="Kích thước file (bytes)")
    mime_type: str | None = Field(None, description="MIME type, ví dụ image/png")
    description: str | None = Field(
        None, description="Mo ta ngan ve attachment (neu co)"
    )
    created_at: datetime | None = Field(
        None, description="Thoi diem upload (UTC)"
    )

    model_config = ConfigDict(from_attributes=True)


# ===========================================================================
# History Schemas
# ===========================================================================


class BugReportHistoryOut(BaseModel):
    """Một entry trong audit trail (status / assignee change)."""

    history_id: uuid.UUID = Field(..., description="UUID của history entry")
    changed_by: dict | None = Field(
        None,
        description="Thông tin user đã thay đổi (user_id, username, role)",
    )
    old_status: BugStatusEnum | None = Field(
        None, description="Trạng thái cũ trước khi thay đổi"
    )
    new_status: BugStatusEnum | None = Field(
        None, description="Trạng thái mới sau khi thay đổi"
    )
    old_teacher_id: uuid.UUID | None = Field(
        None, description="UUID teacher cũ (nếu có)"
    )
    new_teacher_id: uuid.UUID | None = Field(
        None, description="UUID teacher mới (nếu có)"
    )
    comment: str | None = Field(
        None, description="Ghi chú kèm theo thay đổi (nếu có)"
    )
    created_at: datetime = Field(
        ..., description="Thời điểm tạo entry (UTC)"
    )

    model_config = ConfigDict(from_attributes=True)


# ===========================================================================
# Request: Create Bug Report
# ===========================================================================


class BugReportCreate(BaseModel):
    """Payload cho ``POST /api/bug-reports``.

    Form fields gửi kèm attachments (multipart/form-data).
    Device metadata (app_version, build_number, os_version, device_model,
    network_type) được gửi từ Flutter app.
    """

    title: Annotated[str, Field(min_length=1, max_length=200)] = Field(
        ...,
        description="Tiêu đề ngắn gọn của bug, tối đa 200 ký tự",
        examples=["App bị crash khi mở report"],
    )
    description: Annotated[str, Field(min_length=1, max_length=4000)] = Field(
        ...,
        description="Mô tả chi tiết, tối đa 4000 ký tự",
        examples=[
            "Khi em bấm vào report của bé An, app thoát ra ngay. "
            "Đã thử 3 lần đều crash."
        ],
    )
    category: BugCategoryEnum = Field(
        default="other",
        description="Loại lỗi: ui | performance | crash | data | notification | network | auth | other",
    )
    severity: BugSeverityEnum = Field(
        default="medium",
        description="Mức độ nghiêm trọng: low | medium | high | critical",
    )
    # --- Device & environment metadata (gửi từ Flutter app) ---
    app_version: str | None = Field(
        None, max_length=50, description="App version, ví dụ 1.2.3"
    )
    build_number: str | None = Field(
        None, max_length=50, description="Build number, ví dụ 42"
    )
    os_version: str | None = Field(
        None,
        max_length=100,
        description="Device OS, ví dụ 'Android 14' hoặc 'iOS 17.2'",
    )
    device_model: str | None = Field(
        None, max_length=200, description="Device model, ví dụ 'Samsung Galaxy S23'"
    )
    network_type: str | None = Field(
        None,
        max_length=20,
        description="Loại mạng khi xảy ra bug: wifi | cellular | offline",
    )

    @field_validator("title", "description", mode="before")
    @classmethod
    def strip_whitespace(cls, v):
        """Trim leading/trailing whitespace; reject empty strings."""
        if isinstance(v, str):
            v = v.strip()
            if not v:
                raise ValueError("Không được để trống")
        return v


# ===========================================================================
# Request: Update Bug Report (admin)
# ===========================================================================


class BugReportUpdate(BaseModel):
    """Payload cho ``PATCH /api/bug-reports/{id}`` (chỉ admin).

    Admin có thể đổi status, gán teacher, hoặc thêm ghi chú.
    Mọi thay đổi status/assignee đều được ghi vào ``bug_report_history``.
    """

    status: BugStatusEnum | None = Field(
        None,
        description="Trạng thái mới (open / in_progress / resolved / closed / wont_fix)",
    )
    teacher_id: uuid.UUID | None = Field(
        None,
        description="UUID của teacher được gán xử lý bug này (null = bỏ gán)",
    )
    comment: str | None = Field(
        None,
        max_length=2000,
        description="Ghi chú nội bộ về thay đổi này (optional)",
    )

    @field_validator("comment", mode="before")
    @classmethod
    def strip_comment(cls, v):
        if isinstance(v, str):
            v = v.strip()
            if not v:
                return None
        return v


# ===========================================================================
# Query: Filter Bug Reports (admin)
# ===========================================================================


class BugReportFilter(BaseModel):
    """Query parameters cho ``GET /api/bug-reports`` (admin only).

    Hỗ trợ filter theo status, severity, category, role, user_id,
    teacher_id và khoảng thời gian tạo. Tất cả optional.
    """

    status: BugStatusEnum | None = Field(
        None, description="Lọc theo trạng thái"
    )
    severity: BugSeverityEnum | None = Field(
        None, description="Lọc theo mức độ nghiêm trọng"
    )
    category: BugCategoryEnum | None = Field(
        None, description="Lọc theo loại lỗi"
    )
    user_id: uuid.UUID | None = Field(
        None, description="Lọc theo user đã gửi report"
    )
    teacher_id: uuid.UUID | None = Field(
        None, description="Lọc theo teacher được gán"
    )
    user_role: Literal["teacher", "parent", "admin"] | None = Field(
        None, description="Lọc theo role của user gửi report"
    )
    search: str | None = Field(
        None,
        max_length=200,
        description="Tìm kiếm theo title (case-insensitive substring)",
    )
    date_from: datetime | None = Field(
        None, description="Lọc reports từ thời điểm này trở đi (UTC)"
    )
    date_to: datetime | None = Field(
        None, description="Lọc reports đến thời điểm này (UTC)"
    )

    model_config = ConfigDict(from_attributes=True)


# ===========================================================================
# Response: Bug Report (basic)
# ===========================================================================


class BugReportOut(BaseModel):
    """Response cơ bản cho 1 bug report (không bao gồm attachments/history)."""

    bug_report_id: uuid.UUID = Field(..., description="UUID của bug report")
    user: dict = Field(..., description="Thông tin user đã gửi report")
    teacher: dict | None = Field(
        None, description="Thông tin teacher được gán (nếu có)"
    )
    title: str = Field(..., description="Tiêu đề")
    description: str = Field(..., description="Mô tả chi tiết")
    category: BugCategoryEnum = Field(..., description="Loại lỗi")
    severity: BugSeverityEnum = Field(..., description="Mức độ nghiêm trọng")
    status: BugStatusEnum = Field(..., description="Trạng thái hiện tại")
    app_version: str | None = Field(None, description="App version")
    build_number: str | None = Field(None, description="Build number")
    os_version: str | None = Field(None, description="OS version")
    device_model: str | None = Field(None, description="Device model")
    network_type: str | None = Field(None, description="Network type")
    resolved_at: datetime | None = Field(
        None, description="Thời điểm resolved (nếu có)"
    )
    closed_at: datetime | None = Field(
        None, description="Thời điểm closed (nếu có)"
    )
    attachment_count: int = Field(
        0, description="Số lượng attachments"
    )
    created_at: datetime = Field(..., description="Thời điểm tạo (UTC)")
    updated_at: datetime = Field(..., description="Thời điểm cập nhật (UTC)")

    model_config = ConfigDict(from_attributes=True)


# ===========================================================================
# Response: Bug Report Detail (with attachments + history)
# ===========================================================================


class BugReportDetail(BaseModel):
    """Response chi tiết: bao gồm đầy đủ attachments + history.

    Dùng cho ``GET /api/bug-reports/{id}`` và ``GET /api/bug-reports/me/{id}``.
    """

    bug_report_id: uuid.UUID = Field(..., description="UUID của bug report")
    user: dict = Field(..., description="Thông tin user đã gửi report")
    teacher: dict | None = Field(
        None, description="Thông tin teacher được gán (nếu có)"
    )
    title: str = Field(..., description="Tiêu đề")
    description: str = Field(..., description="Mô tả chi tiết")
    category: BugCategoryEnum = Field(..., description="Loại lỗi")
    severity: BugSeverityEnum = Field(..., description="Mức độ nghiêm trọng")
    status: BugStatusEnum = Field(..., description="Trạng thái hiện tại")
    app_version: str | None = Field(None, description="App version")
    build_number: str | None = Field(None, description="Build number")
    os_version: str | None = Field(None, description="OS version")
    device_model: str | None = Field(None, description="Device model")
    network_type: str | None = Field(None, description="Network type")
    resolved_at: datetime | None = Field(
        None, description="Thời điểm resolved (nếu có)"
    )
    closed_at: datetime | None = Field(
        None, description="Thời điểm closed (nếu có)"
    )
    attachments: list[BugReportAttachmentOut] = Field(
        default_factory=list, description="Danh sách file đính kèm"
    )
    history: list[BugReportHistoryOut] = Field(
        default_factory=list,
        description="Lịch sử thay đổi trạng thái/assignee",
    )
    created_at: datetime = Field(..., description="Thời điểm tạo (UTC)")
    updated_at: datetime = Field(..., description="Thời điểm cập nhật (UTC)")

    model_config = ConfigDict(from_attributes=True)


# ===========================================================================
# Response: List with Pagination
# ===========================================================================


class BugReportListResponse(BaseModel):
    """Response phân trang cho ``GET /api/bug-reports`` và ``/me``."""

    items: list[BugReportOut] = Field(
        default_factory=list, description="Danh sách bug reports"
    )
    total: int = Field(..., description="Tổng số records (theo filter)")
    page: int = Field(..., description="Trang hiện tại (1-indexed)")
    page_size: int = Field(..., description="Số item / trang")
    total_pages: int = Field(..., description="Tổng số trang")
    has_next: bool = Field(..., description="Có trang kế tiếp không")
    has_prev: bool = Field(..., description="Có trang trước không")


# ===========================================================================
# Response: Upload Attachment(s)
# ===========================================================================


class BugReportAttachmentListResponse(BaseModel):
    """Response cho ``POST /api/bug-reports/{id}/attachments``."""

    bug_report_id: uuid.UUID = Field(..., description="UUID của report")
    attachments: list[BugReportAttachmentOut] = Field(
        ..., description="Danh sách attachments vừa upload"
    )
    total_attachments: int = Field(
        ..., description="Tổng số attachments của report sau khi upload"
    )


# ===========================================================================
# Response: Rate Limit Status
# ===========================================================================


class BugReportRateLimitInfo(BaseModel):
    """Optional: trả về cùng response 201 khi tạo report.

    Frontend dùng để hiển thị cảnh báo "Bạn còn X lượt gửi trong 1h".
    """

    used: int = Field(..., description="Số report đã gửi trong 1h qua")
    limit: int = Field(..., description="Giới hạn tối đa trong 1h")
    reset_at: datetime = Field(
        ..., description="Thời điểm reset rate limit (UTC)"
    )


# ===========================================================================
# ORM → Pydantic conversion helpers
# ===========================================================================


def bug_report_to_out(report) -> dict:
    """Convert ORM ``BugReport`` → dict cho ``BugReportOut``."""
    return {
        "bug_report_id": report.bug_report_id,
        "user": _user_summary(report.user) or {},
        "teacher": _teacher_summary(report.teacher),
        "title": report.title,
        "description": report.description,
        "category": report.category.value,
        "severity": report.severity.value,
        "status": report.status.value,
        "app_version": report.app_version,
        "build_number": report.build_number,
        "os_version": report.os_version,
        "device_model": report.device_model,
        "network_type": report.network_type,
        "resolved_at": report.resolved_at,
        "closed_at": report.closed_at,
        "attachment_count": len(report.attachments) if report.attachments else 0,
        "created_at": report.created_at,
        "updated_at": report.updated_at,
    }


def bug_report_to_detail(report) -> dict:
    """Convert ORM ``BugReport`` → dict cho ``BugReportDetail``."""
    base = bug_report_to_out(report)
    base["attachments"] = [
        BugReportAttachmentOut.model_validate(att).model_dump()
        for att in (report.attachments or [])
    ]
    base["history"] = [
        {
            "history_id": h.history_id,
            "changed_by": _user_summary(h.changed_by) if h.changed_by else None,
            "old_status": h.old_status.value if h.old_status else None,
            "new_status": h.new_status.value if h.new_status else None,
            "old_teacher_id": h.old_teacher_id,
            "new_teacher_id": h.new_teacher_id,
            "comment": h.comment,
            "created_at": h.created_at,
        }
        for h in (report.history or [])
    ]
    return base


# Re-export for convenience
__all__ = [
    "BugCategory",
    "BugCategoryEnum",
    "BugReportAttachmentListResponse",
    "BugReportAttachmentOut",
    "BugReportCreate",
    "BugReportDetail",
    "BugReportFilter",
    "BugReportHistoryOut",
    "BugReportListResponse",
    "BugReportOut",
    "BugReportRateLimitInfo",
    "BugReportUpdate",
    "BugSeverity",
    "BugSeverityEnum",
    "BugStatus",
    "BugStatusEnum",
    "bug_report_to_detail",
    "bug_report_to_out",
]
