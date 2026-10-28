"""
backend/app/schemas/medication_schema.py
========================================
Pydantic Schemas cho API Dặn thuốc / Uống thuốc của Giáo viên & Phụ huynh:
- Task #283: GET /api/teacher/medications/today
- 1-tap confirmation: POST /api/teacher/medications/confirm
"""

from __future__ import annotations

import datetime as dt
import uuid
from pydantic import BaseModel, ConfigDict, Field


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
