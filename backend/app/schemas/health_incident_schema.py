"""
backend/app/schemas/health_incident_schema.py
=============================================
Pydantic Schemas cho API Cảnh báo sự cố sức khỏe khẩn cấp tại lớp (Task #285):
- Thiết kế tối ưu cho tình huống khẩn cấp: Hỗ trợ 1 chạm (Zero typing required).
- Trả về danh sách số điện thoại khẩn cấp của bố/mẹ để cô bấm gọi trực tiếp ngay trên màn hình.
"""

from __future__ import annotations

import datetime as dt
import uuid
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.health_incident import HealthIncidentType


class EmergencyContactInfo(BaseModel):
    """Thông tin liên lạc khẩn cấp của phụ huynh."""
    model_config = ConfigDict(from_attributes=True)

    name: str = Field(..., description="Họ tên người liên hệ")
    relationship: str = Field(..., description="Quan hệ với bé (Bố, Mẹ, Người giám hộ)")
    phone: str = Field(..., description="Số điện thoại gọi khẩn cấp")


class HealthIncidentCreate(BaseModel):
    """
    Payload phát cảnh báo khẩn cấp (1 chạm):
    - Chỉ cần child_id và incident_type (chọn từ nút bấm to trên giao diện).
    - Các trường description, temperature, action_taken đều là tuỳ chọn (optional).
    """
    child_id: uuid.UUID = Field(..., description="ID của bé gặp sự cố khẩn cấp")
    incident_type: HealthIncidentType = Field(
        default=HealthIncidentType.HIGH_FEVER,
        description="Loại sự cố: high_fever (Sốt cao), severe_injury (Tai nạn), acute_allergy (Dị ứng), other (Khác)",
    )

    @field_validator("incident_type", mode="before")
    @classmethod
    def normalize_incident_type(cls, v: object) -> object:
        if isinstance(v, str):
            return v.strip().lower()
        return v
    description: str | None = Field(
        None,
        description="Mô tả sự cố (tuỳ chọn - nếu để trống sẽ tự động sinh câu mô tả khẩn cấp chuẩn)",
    )
    temperature: float | None = Field(
        None,
        ge=34.0,
        le=44.0,
        description="Nhiệt độ cơ thể (°C) nếu là trường hợp sốt cao",
    )
    action_taken: str | None = Field(
        None,
        description="Biện pháp sơ cứu đã thực hiện tại lớp (tuỳ chọn)",
    )


class HealthIncidentUpdate(BaseModel):
    """Payload bổ sung thông tin biên bản sự việc sau khi tình hình đã ổn định."""
    description: str | None = Field(None, description="Cập nhật chi tiết diễn biến sự cố")
    temperature: float | None = Field(None, ge=34.0, le=44.0, description="Cập nhật nhiệt độ")
    action_taken: str | None = Field(None, description="Cập nhật các biện pháp xử lý/sơ cứu đã thực hiện")


class HealthIncidentResponse(BaseModel):
    """Kết quả phát cảnh báo khẩn cấp kèm danh bạ gọi trực tiếp tới bố/mẹ."""
    model_config = ConfigDict(from_attributes=True)

    incident_id: uuid.UUID = Field(..., description="Mã sự cố")
    child_id: uuid.UUID = Field(..., description="Mã học sinh")
    child_name: str = Field(..., description="Họ tên học sinh")
    child_nickname: str | None = Field(None, description="Tên thân mật của bé")
    child_avatar_url: str | None = Field(None, description="Ảnh đại diện của bé")
    class_id: uuid.UUID = Field(..., description="Mã lớp học")

    incident_type: str = Field(..., description="Mã loại sự cố")
    incident_type_label: str = Field(..., description="Nhãn tiếng Việt: Sốt cao, Tai nạn, Dị ứng cấp...")
    description: str = Field(..., description="Mô tả sự cố")
    temperature: float | None = Field(None, description="Nhiệt độ (°C)")
    action_taken: str | None = Field(None, description="Biện pháp sơ cứu đã xử lý")

    reported_at: dt.datetime = Field(..., description="Thời gian phát cảnh báo")
    reported_by_id: uuid.UUID | None = Field(None, description="Mã giáo viên báo cáo")
    reported_by_name: str | None = Field(None, description="Tên giáo viên phát cảnh báo")

    emergency_contacts: list[EmergencyContactInfo] = Field(
        default_factory=list,
        description="Danh sách liên lạc khẩn cấp của bố mẹ để cô bấm gọi ngay",
    )


class ChildEmergencyContactsResponse(BaseModel):
    """Danh bạ khẩn cấp của học sinh để cô tra cứu và bấm gọi ngay lập tức."""
    model_config = ConfigDict(from_attributes=True)

    child_id: uuid.UUID
    child_name: str
    class_name: str | None = None
    emergency_contacts: list[EmergencyContactInfo]
