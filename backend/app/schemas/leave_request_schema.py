"""
app/schemas/leave_request_schema.py
===================================
Pydantic schemas cho API Đơn xin nghỉ học (Leave Request):
- Request/Response cho tạo đơn, duyệt đơn, từ chối đơn
- DTO danh sách đơn xin nghỉ học của lớp
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field

from app.models.leave_request import LeaveRequestStatus


class LeaveRequestCreate(BaseModel):
    """Schema tạo đơn xin nghỉ học mới."""
    child_id: uuid.UUID
    class_id: uuid.UUID
    from_date: date
    to_date: date
    reason: str = Field(..., min_length=3, max_length=1000, description="Lý do xin nghỉ")
    attachment_url: str | None = Field(default=None, max_length=500)


class LeaveRequestReject(BaseModel):
    """Schema từ chối đơn xin nghỉ (bắt buộc nhập lý do)."""
    reject_reason: str = Field(..., min_length=2, max_length=500, description="Lý do từ chối đơn")


class LeaveRequestChildInfo(BaseModel):
    """Thông tin tóm tắt học sinh trong đơn xin nghỉ."""
    child_id: uuid.UUID
    full_name: str
    nickname: str | None = None
    avatar_url: str | None = None

    model_config = ConfigDict(from_attributes=True)


class LeaveRequestResponse(BaseModel):
    """Schema phản hồi chi tiết đơn xin nghỉ học."""
    request_id: uuid.UUID
    child_id: uuid.UUID
    parent_id: uuid.UUID
    class_id: uuid.UUID
    from_date: date
    to_date: date
    reason: str
    attachment_url: str | None = None
    status: LeaveRequestStatus
    reject_reason: str | None = None
    reviewed_by: uuid.UUID | None = None
    reviewed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    # Thông tin bổ trợ cho UI giáo viên hiển thị
    child_name: str | None = None
    child_avatar_url: str | None = None
    parent_name: str | None = None
    reviewer_name: str | None = None

    model_config = ConfigDict(from_attributes=True)


class LeaveRequestBatchSummary(BaseModel):
    """Tóm tắt số lượng đơn theo trạng thái."""
    pending_count: int
    reviewed_count: int
    items: list[LeaveRequestResponse]
