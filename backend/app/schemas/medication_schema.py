"""
backend/app/schemas/medication_schema.py
========================================
Pydantic Schemas cho API Dặn thuốc / Uống thuốc của Giáo viên & Phụ huynh:
- Task #283 & #284: GET /api/teacher/medications/today & confirm
- User Story 3.1: Dặn thuốc đa cữ, dài ngày & ảnh đơn thuốc
"""

from __future__ import annotations

import datetime as dt
import uuid
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.medication import MedicationStatus, MedicineCategory


# ===========================================================================
# 1. Schemas cho Giáo viên xem danh sách hôm nay & 1-chạm xác nhận (Task #283, #284)
# ===========================================================================
class MedicationItemResponse(BaseModel):
    """Chi tiết 1 lượt cần uống thuốc của học sinh trong buổi cụ thể."""

    model_config = ConfigDict(from_attributes=True)

    request_id: uuid.UUID = Field(..., description="ID đơn dặn thuốc")
    child_id: uuid.UUID = Field(..., description="ID học sinh")
    child_name: str = Field(..., description="Họ và tên học sinh")
    child_nickname: str | None = Field(None, description="Tên thường gọi/biệt danh của bé")
    child_avatar_url: str | None = Field(None, description="Ảnh đại diện của bé")

    medication_name: str = Field(..., description="Tên thuốc cần uống")
    dosage: str = Field(..., description="Liều lượng (vd: 5ml, 1 viên, 1 gói)")
    instructions: str | None = Field(None, description="Hướng dẫn sử dụng từ phụ huynh")
    session: str = Field(..., description="Mốc thời gian: morning, noon, afternoon")

    is_given: bool = Field(False, description="Đã cho uống thuốc buổi này chưa")
    given_at: dt.datetime | None = Field(None, description="Thời điểm cô đã cho uống")
    given_by_id: uuid.UUID | None = Field(None, description="ID của giáo viên đã cho uống")
    given_by_name: str | None = Field(None, description="Tên giáo viên đã cho uống (vd: Cô Lan)")

    notes: str | None = Field(None, description="Ghi chú thêm")
    parent_name: str | None = Field(None, description="Tên phụ huynh liên hệ")
    parent_phone: str | None = Field(None, description="Số điện thoại phụ huynh (dùng cho gọi khẩn cấp)")


class MedicationsTodayResponse(BaseModel):
    """
    Danh sách dặn thuốc của lớp trong ngày hôm nay:
    Gom nhóm theo 3 ca: Sáng (morning), Trưa (noon), Chiều (afternoon).
    """

    model_config = ConfigDict(from_attributes=True)

    date: dt.date = Field(..., description="Ngày xem dữ liệu")
    class_id: uuid.UUID = Field(..., description="ID lớp học")
    class_name: str | None = Field(None, description="Tên lớp học")

    total_requests: int = Field(0, description="Tổng số lượt uống thuốc cần thực hiện trong ngày")
    completed_count: int = Field(0, description="Số lượt đã cho uống")
    pending_count: int = Field(0, description="Số lượt chưa cho uống")

    morning: list[MedicationItemResponse] = Field(
        default_factory=list,
        description="Danh sách các bé cần uống thuốc buổi Sáng",
    )
    noon: list[MedicationItemResponse] = Field(
        default_factory=list,
        description="Danh sách các bé cần uống thuốc buổi Trưa",
    )
    afternoon: list[MedicationItemResponse] = Field(
        default_factory=list,
        description="Danh sách các bé cần uống thuốc buổi Chiều",
    )


class MedicationConfirmPayload(BaseModel):
    """Payload gửi lên từ app khi xác nhận đã cho uống thuốc."""

    session: str = Field(..., description="Buổi uống: morning, noon, afternoon")
    notes: str | None = Field(None, description="Ghi chú thêm của cô (vd: bé uống ngoan)")


class MedicationConfirmRequest(MedicationConfirmPayload):
    """Payload xác nhận có kèm request_id trong body."""

    request_id: uuid.UUID | None = Field(None, description="ID đơn dặn thuốc (tuỳ chọn nếu đã truyền trên URL)")


class MedicationConfirmResponse(BaseModel):
    """Kết quả xác nhận cho trẻ uống thuốc."""

    success: bool = True
    message: str
    log_id: uuid.UUID
    request_id: uuid.UUID
    session: str
    is_given: bool
    given_by_name: str | None
    given_at: dt.datetime


# ===========================================================================
# 2. Schemas cho Phụ huynh tạo đơn & theo dõi chi tiết (User Story 3.1)
# ===========================================================================
class MedicationRequestCreate(BaseModel):
    """Schema tạo đơn dặn thuốc (hỗ trợ dải ngày và nhiều cữ uống)."""

    child_id: uuid.UUID
    from_date: dt.date = Field(default_factory=dt.date.today, description="Ngày bắt đầu uống thuốc")
    to_date: dt.date | None = Field(None, description="Ngày kết thúc uống thuốc (tối đa 7 ngày)")
    time_slots: list[str] = Field(..., min_length=1, description="Các khung giờ uống trong ngày, ví dụ ['08:30', '11:30']")
    medicine_category: MedicineCategory = Field(default=MedicineCategory.PRESCRIPTION)
    medicine_name: str | None = Field(None, max_length=255)
    dosage: str = Field(..., min_length=1, max_length=255, description="Liều lượng hoặc quy cách gói thuốc")
    notes: str | None = Field(None, max_length=1000)
    prescription_image_url: str = Field(..., min_length=1, max_length=512, description="Ảnh đơn thuốc hoặc bao bì chia liều")

    @field_validator("prescription_image_url")
    @classmethod
    def validate_image_url(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Ảnh đơn thuốc hoặc bao bì thuốc là bắt buộc.")
        return v.strip()

    @field_validator("time_slots")
    @classmethod
    def validate_time_slots(cls, v: list[str]) -> list[str]:
        cleaned: list[str] = []
        for slot in v:
            s = slot.strip()
            parts = s.split(":")
            if len(parts) != 2 or not all(p.isdigit() for p in parts):
                raise ValueError(f"Khung giờ '{slot}' không đúng định dạng HH:MM.")
            h, m = int(parts[0]), int(parts[1])
            if not (0 <= h <= 23 and 0 <= m <= 59):
                raise ValueError(f"Khung giờ '{slot}' không hợp lệ.")
            cleaned.append(f"{h:02d}:{m:02d}")
        if not cleaned:
            raise ValueError("Phải có ít nhất 1 khung giờ uống thuốc.")
        return list(dict.fromkeys(cleaned))


class MedicationRequestResponse(BaseModel):
    """Schema chi tiết cữ uống thuốc trả về."""

    id: uuid.UUID
    batch_id: uuid.UUID
    child_id: uuid.UUID
    child_name: str
    class_id: uuid.UUID
    class_name: str | None = None
    parent_id: uuid.UUID
    parent_name: str | None = None
    request_date: dt.date
    time_slot: str
    medicine_category: MedicineCategory
    medicine_name: str | None = None
    dosage: str
    notes: str | None = None
    prescription_image_url: str
    status: MedicationStatus
    created_by_user_id: uuid.UUID
    created_by_role: str
    creator_name: str
    given_at: dt.datetime | None = None
    given_by_id: uuid.UUID | None = None
    given_by_name: str | None = None
    created_at: dt.datetime
    updated_at: dt.datetime

    model_config = ConfigDict(from_attributes=True)


class MedicationBatchCreateResponse(BaseModel):
    """Phản hồi sau khi tạo đợt dặn thuốc."""

    batch_id: uuid.UUID
    total_slots: int
    items: list[MedicationRequestResponse]
    message: str
