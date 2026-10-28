"""
app/schemas/leave_request_schema.py
===================================
Pydantic schemas cho API Đơn xin nghỉ học (Leave Request):
- Request/Response cho tạo đơn, duyệt đơn, từ chối đơn
- DTO danh sách đơn xin nghỉ học của lớp
"""

from __future__ import annotations

import uuid
import re
from datetime import date, datetime, time
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.leave_request import LeaveRequestStatus


class LeaveRequestCreate(BaseModel):
    """Schema tạo đơn xin nghỉ học mới."""
    child_id: uuid.UUID
    class_id: uuid.UUID | None = None
    from_date: date
    to_date: date
    reason: str = Field(..., min_length=3, max_length=1000, description="Lý do xin nghỉ")
    attachment_url: str | None = Field(default=None, max_length=500)
    request_type: Literal["absence", "late_arrival"] = "absence"
    expected_arrival_time: time | None = None
    meal_warning_acknowledged: bool = False

    @field_validator("reason", mode="before")
    @classmethod
    def trim_reason(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("from_date", "to_date", mode="before")
    @classmethod
    def validate_date_format(cls, value):
        if isinstance(value, date) and not isinstance(value, datetime):
            return value
        if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise ValueError("Ngày phải có định dạng YYYY-MM-DD")
        return value

    @field_validator("expected_arrival_time", mode="before")
    @classmethod
    def validate_time_format(cls, value):
        if value is not None and (
            not isinstance(value, str) or not re.fullmatch(r"\d{2}:\d{2}:\d{2}", value)
        ):
            raise ValueError("Giờ đến dự kiến phải có định dạng HH:mm:ss")
        return value

    @model_validator(mode="after")
    def validate_range_and_type(self):
        if not 0 <= (self.to_date - self.from_date).days < 366:
            raise ValueError("Khoảng ngày không hợp lệ hoặc vượt quá 366 ngày")
        if self.request_type == "late_arrival":
            if self.from_date != self.to_date or self.expected_arrival_time is None:
                raise ValueError("Báo trễ chỉ cho một ngày và phải có giờ đến dự kiến")
        elif self.expected_arrival_time is not None:
            raise ValueError("Đơn xin nghỉ không có giờ đến dự kiến")
        return self


class LeaveRequestReject(BaseModel):
    """Schema từ chối đơn xin nghỉ (bắt buộc nhập lý do)."""
    reject_reason: str = Field(..., min_length=2, max_length=500, description="Lý do từ chối đơn")

    @field_validator("reject_reason", mode="before")
    @classmethod
    def trim_reason(cls, value):
        return value.strip() if isinstance(value, str) else value


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
    request_type: Literal["absence", "late_arrival"] = "absence"
    expected_arrival_time: time | None = None
    meal_warning_acknowledged: bool = False
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


class LeaveRequestPage(BaseModel):
    """Lịch sử đơn của bé, phân trang theo thứ tự mới nhất."""
    items: list[LeaveRequestResponse]
    total: int
    offset: int
    limit: int


class LeaveRequestAttachmentResponse(BaseModel):
    """Tham chiếu ảnh qua API có kiểm quyền, không phải URL MinIO public."""
    attachment_url: str
