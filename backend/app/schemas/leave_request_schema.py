"""
app/schemas/leave_request_schema.py
===================================
Hỗ trợ tạo đơn cho 1 hoặc nhiều bé (áp dụng chung hoặc riêng lịch nghỉ).
"""

from __future__ import annotations

import re
import uuid
from datetime import date, datetime, time

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.leave_request import LeaveStatus, LeaveType

ALLOWED_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".pdf")


class ChildScheduleInput(BaseModel):
    """Lịch nghỉ của từng bé (được gán chung nếu bật nút gạt, hoặc riêng nếu tắt nút gạt)."""

    child_id: uuid.UUID = Field(..., description="ID học sinh")
    type: LeaveType = Field(default=LeaveType.SINGLE_DAY, description="single_day | multi_day | late")
    from_date: date = Field(default_factory=date.today, description="Ngày bắt đầu (mặc định hôm nay)")
    to_date: date | None = Field(None, description="Ngày kết thúc")
    expected_arrival_time: time | None = Field(None, description="Giờ dự kiến đến (chỉ dùng khi type = late)")

    @model_validator(mode="after")
    def validate_schedule(self) -> ChildScheduleInput:
        today = date.today()
        if self.from_date < today:
            raise ValueError("Không thể gửi đơn xin phép cho ngày trong quá khứ.")

        # Tự động gán to_date = from_date cho đơn 1 ngày và đi trễ
        if self.type in (LeaveType.SINGLE_DAY, LeaveType.LATE):
            self.to_date = self.from_date

        if self.type == LeaveType.LATE:
            if self.expected_arrival_time is None:
                raise ValueError("Vui lòng chọn thời gian dự kiến đến lớp khi báo đi trễ.")
        else:
            self.expected_arrival_time = None

        if self.type == LeaveType.MULTI_DAY:
            if self.to_date is None or self.to_date <= self.from_date:
                raise ValueError("Đơn nghỉ nhiều ngày yêu cầu ngày kết thúc phải sau ngày bắt đầu.")

        return self


class LeaveRequestCreate(BaseModel):
    """Payload tạo đơn chính - Gom chung Lý do, SĐT và Ảnh."""

    children: list[ChildScheduleInput] = Field(
        ...,
        min_length=1,
        description="Danh sách bé kèm lịch nghỉ (chọn 1 bé hoặc nhiều bé)",
    )
    reason: str = Field(..., description="Lý do xin phép chung")
    attachment_url: str | None = Field(None, description="URL ảnh minh chứng")
    contact_phone: str | None = Field(
        None,
        description="SĐT 10 số. Nếu bỏ trống backend sẽ tự điền từ tài khoản phụ huynh.",
    )

    @field_validator("children")
    @classmethod
    def validate_unique_children(cls, v: list[ChildScheduleInput]) -> list[ChildScheduleInput]:
        ids = [item.child_id for item in v]
        if len(ids) != len(set(ids)):
            raise ValueError("Danh sách học sinh có ID bị trùng lặp.")
        return v

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, v: str) -> str:
        cleaned = v.strip()
        if len(cleaned) < 3:
            raise ValueError("Lý do xin phép quá ngắn, vui lòng nhập tối thiểu 3 ký tự.")
        if len(cleaned) > 500:
            raise ValueError(f"Lý do xin phép dài {len(cleaned)} ký tự, vượt quá giới hạn 500 ký tự.")
        return cleaned

    @field_validator("attachment_url")
    @classmethod
    def validate_attachment(cls, v: str | None) -> str | None:
        if v and v.strip():
            url_clean = v.strip().lower().split("?")[0]
            if not any(url_clean.endswith(ext) for ext in ALLOWED_EXTENSIONS):
                raise ValueError("Tệp đính kèm không hợp lệ. Chỉ chấp nhận JPG, JPEG, PNG, WEBP, HEIC hoặc PDF.")
            return v.strip()
        return None

    @field_validator("contact_phone")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        if v and v.strip():
            phone = v.strip()
            if not re.match(r"^0\d{9}$", phone):
                raise ValueError("Số điện thoại phải có đúng 10 chữ số và bắt đầu bằng số 0.")
            return phone
        return None


class LeaveRequestResponse(BaseModel):
    """Thông tin đơn của 1 bé sau khi tạo."""

    leave_id: uuid.UUID
    child_id: uuid.UUID
    child_name: str
    class_id: uuid.UUID
    type: LeaveType
    from_date: date
    to_date: date
    expected_arrival_time: time | None = None
    reason: str
    attachment_url: str | None = None
    contact_phone: str
    status: LeaveStatus
    submitted_after_cutoff: bool
    warning_message: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class LeaveBatchCreateResponse(BaseModel):
    """Response trả về khi tạo xong cho 1 hoặc nhiều bé."""

    total_created: int
    requests: list[LeaveRequestResponse]

class StudentLeaveHistoryItem(BaseModel):
    """Thông tin chi tiết một đơn trong lịch sử của bé."""

    leave_id: uuid.UUID
    type: LeaveType
    from_date: date
    to_date: date
    expected_arrival_time: time | None = None
    reason: str
    attachment_url: str | None = None
    contact_phone: str
    status: LeaveStatus
    submitted_after_cutoff: bool
    approved_by_name: str | None = None
    reject_reason: str | None = None
    action_at: datetime | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class StudentLeaveHistoryResponse(BaseModel):
    """Response trả về cho màn hình lịch sử đơn của bé."""

    child_id: uuid.UUID
    child_name: str
    class_id: uuid.UUID
    class_name: str | None = None
    total_requests: int
    data: list[StudentLeaveHistoryItem]


class LeaveRequestReject(BaseModel):
    """Payload từ chối đơn."""
    reason: str = Field(..., min_length=3, max_length=500, description="Lý do từ chối đơn")


class LeaveRequestReviewResponse(BaseModel):
    """Kết quả duyệt hoặc từ chối đơn từ giáo viên."""
    success: bool
    message: str
    leave_id: uuid.UUID
    status: LeaveStatus
    synced_attendance_count: int = 0


class LeaveRequestCancelResponse(BaseModel):
    """Kết quả huỷ đơn từ phụ huynh."""
    success: bool
    message: str
    leave_id: uuid.UUID
    status: LeaveStatus
    rollbacked_attendance: bool = False


class LeaveRequestBatchSummary(BaseModel):
    """Tổng hợp danh sách đơn theo lớp cho giáo viên."""
    pending_count: int
    reviewed_count: int
    items: list[StudentLeaveHistoryItem]

