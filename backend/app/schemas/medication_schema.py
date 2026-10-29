"""
app/schemas/medication_schema.py
================================
Pydantic Schemas for Medication Requests.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from pydantic import BaseModel, Field, field_validator

from app.models.medication import MedicationStatus, MedicineCategory


class MedicationRequestCreate(BaseModel):
    """Schema tạo đơn dặn thuốc (hỗ trợ dải ngày và nhiều cữ uống)."""

    child_id: uuid.UUID
    from_date: date = Field(default_factory=date.today, description="Ngày bắt đầu uống thuốc")
    to_date: date | None = Field(None, description="Ngày kết thúc uống thuốc (tối đa 7 ngày)")
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
        # Giữ thứ tự và loại bỏ trùng lặp
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
    request_date: date
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
    given_at: datetime | None = None
    given_by_id: uuid.UUID | None = None
    given_by_name: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MedicationBatchCreateResponse(BaseModel):
    """Phản hồi sau khi tạo đợt dặn thuốc."""

    batch_id: uuid.UUID
    total_slots: int
    items: list[MedicationRequestResponse]
    message: str


class MedicationConfirmRequest(BaseModel):
    """Xác nhận đã cho uống thuốc."""

    notes: str | None = Field(None, max_length=500, description="Ghi chú khi cho uống (nếu có)")
