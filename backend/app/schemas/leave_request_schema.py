"""Hợp đồng chung cho API batch mới và giao diện phụ huynh một bé."""

from __future__ import annotations

import re
import uuid
from datetime import date, datetime, time
from typing import Literal

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.leave_request import LeaveStatus, LeaveType
from app.config import get_today


class ParentLeaveRequestCreate(BaseModel):
    """Adapter đầu vào một bé; nghiệp vụ ghi dữ liệu dùng chung với batch."""
    child_id: uuid.UUID
    class_id: uuid.UUID | None = None
    from_date: date
    to_date: date
    reason: str = Field(min_length=3, max_length=1000)
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
    def validate_range(self):
        if not 0 <= (self.to_date - self.from_date).days < 366:
            raise ValueError("Khoảng ngày không hợp lệ hoặc vượt quá 366 ngày")
        if self.request_type == "late_arrival":
            if self.from_date != self.to_date or self.expected_arrival_time is None:
                raise ValueError("Báo trễ chỉ cho một ngày và phải có giờ đến dự kiến")
        elif self.expected_arrival_time is not None:
            raise ValueError("Đơn xin nghỉ không có giờ đến dự kiến")
        return self


class ChildScheduleInput(BaseModel):
    child_id: uuid.UUID
    type: LeaveType = LeaveType.SINGLE_DAY
    from_date: date = Field(default_factory=get_today)
    to_date: date | None = None
    expected_arrival_time: time | None = None

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.type in (LeaveType.SINGLE_DAY, LeaveType.LATE):
            if self.to_date is not None and self.to_date != self.from_date:
                raise ValueError("Đơn một ngày hoặc đi trễ chỉ áp dụng một ngày")
            self.to_date = self.from_date
        if self.to_date is None or not 0 <= (self.to_date - self.from_date).days < 366:
            raise ValueError("Khoảng ngày không hợp lệ hoặc vượt quá 366 ngày")
        if self.type == LeaveType.MULTI_DAY and self.from_date == self.to_date:
            raise ValueError("Nghỉ nhiều ngày cần ngày kết thúc sau ngày bắt đầu")
        if self.type == LeaveType.LATE:
            if self.expected_arrival_time is None or self.expected_arrival_time.tzinfo is not None:
                raise ValueError("Báo trễ cần giờ đến dự kiến theo giờ Việt Nam")
        elif self.expected_arrival_time is not None:
            raise ValueError("Đơn xin nghỉ không có giờ đến dự kiến")
        return self


class LeaveRequestCreate(BaseModel):
    """Giữ API batch cho nhiều bé; thời gian thực được kiểm tra tại service."""
    children: list[ChildScheduleInput] = Field(min_length=1, max_length=50)
    reason: str = Field(min_length=3, max_length=1000)
    attachment_url: str | None = Field(default=None, max_length=500)
    contact_phone: str | None = Field(default=None, max_length=20)
    meal_warning_acknowledged: bool = False

    @field_validator("reason", mode="before")
    @classmethod
    def trim_reason(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("children")
    @classmethod
    def unique_children(cls, value):
        if len({item.child_id for item in value}) != len(value):
            raise ValueError("Danh sách học sinh có ID bị trùng lặp")
        return value

    @field_validator("contact_phone")
    @classmethod
    def validate_phone(cls, value):
        if value is None or not value.strip():
            return None
        if not re.fullmatch(r"0\d{9}", value.strip()):
            raise ValueError("Số điện thoại phải có 10 chữ số và bắt đầu bằng 0")
        return value.strip()


class LeaveRequestReject(BaseModel):
    reason: str = Field(min_length=2, max_length=500,
                        validation_alias=AliasChoices("reason", "reject_reason"))

    @field_validator("reason", mode="before")
    @classmethod
    def trim_reason(cls, value):
        return value.strip() if isinstance(value, str) else value


class LeaveRequestResponse(BaseModel):
    """Superset cộng thêm: giữ cả tên trường API mới và client UI đã phát hành."""
    model_config = ConfigDict(from_attributes=True)
    request_id: uuid.UUID
    leave_id: uuid.UUID
    child_id: uuid.UUID
    parent_id: uuid.UUID
    class_id: uuid.UUID
    type: LeaveType
    request_type: Literal["absence", "late_arrival"]
    from_date: date
    to_date: date
    reason: str
    attachment_url: str | None = None
    expected_arrival_time: time | None = None
    meal_warning_acknowledged: bool = False
    submitted_after_cutoff: bool = False
    contact_phone: str = ""
    can_cancel: bool = False
    cancel_before: datetime | None = None
    cancel_block_reason: str | None = None
    status: LeaveStatus
    reject_reason: str | None = None
    reviewed_by: uuid.UUID | None = None
    reviewed_at: datetime | None = None
    action_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    child_name: str | None = None
    child_avatar_url: str | None = None
    parent_name: str | None = None
    reviewer_name: str | None = None
    approved_by_name: str | None = None
    warning_message: str | None = None


class LeaveBatchCreateResponse(BaseModel):
    total_created: int
    requests: list[LeaveRequestResponse]


StudentLeaveHistoryItem = LeaveRequestResponse


class StudentLeaveHistoryResponse(BaseModel):
    child_id: uuid.UUID
    child_name: str
    class_id: uuid.UUID | None
    class_name: str | None = None
    total_requests: int
    data: list[StudentLeaveHistoryItem]


class LeaveRequestReviewResponse(LeaveRequestResponse):
    success: bool
    message: str
    synced_attendance_count: int = 0


class LeaveRequestCancelResponse(BaseModel):
    success: bool
    message: str
    leave_id: uuid.UUID
    status: LeaveStatus
    rollbacked_attendance: bool = False


class LeaveRequestBatchSummary(BaseModel):
    pending_count: int
    reviewed_count: int
    items: list[LeaveRequestResponse]


class LeaveRequestPage(BaseModel):
    items: list[LeaveRequestResponse]
    total: int
    offset: int
    limit: int


class LeaveRequestAttachmentResponse(BaseModel):
    attachment_url: str
