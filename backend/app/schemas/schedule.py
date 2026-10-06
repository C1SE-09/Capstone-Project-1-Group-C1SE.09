"""
app/schemas/schedule.py
========================
Pydantic schemas cho TimeSlot, Subject, và ClassSchedule API requests & responses.
"""

from __future__ import annotations

import uuid
from pydantic import BaseModel, ConfigDict, Field


# ===========================================================================
# TimeSlot Schemas
# ===========================================================================
class TimeSlotBase(BaseModel):
    name: str = Field(..., description="Tên hiển thị khung giờ (vd: 07:00 - 07:30)")
    start_time: str = Field(..., description="Thời gian bắt đầu HH:MM (vd: 07:00)")
    end_time: str = Field(..., description="Thời gian kết thúc HH:MM (vd: 07:30)")
    order_index: int = Field(1, description="Thứ tự sắp xếp trong ngày")


class TimeSlotCreate(TimeSlotBase):
    pass


class TimeSlotUpdate(BaseModel):
    name: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    order_index: int | None = None


class TimeSlotResponse(TimeSlotBase):
    slot_id: uuid.UUID

    model_config = ConfigDict(from_attributes=True)


# ===========================================================================
# Subject Schemas
# ===========================================================================
class SubjectBase(BaseModel):
    name: str = Field(..., description="Tên môn học/hoạt động (vd: Thể dục, Mỹ thuật)")
    code: str | None = Field(None, description="Mã viết tắt (vd: PE, ART)")
    color_code: str | None = Field("#4CAF50", description="Mã màu HEX cho Flutter UI")
    description: str | None = Field(None, description="Mô tả hoặc dụng cụ cần chuẩn bị")


class SubjectCreate(SubjectBase):
    pass


class SubjectUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    color_code: str | None = None
    description: str | None = None


class SubjectResponse(SubjectBase):
    subject_id: uuid.UUID

    model_config = ConfigDict(from_attributes=True)


# ===========================================================================
# Teacher Helper Schema
# ===========================================================================
class TeacherSimpleResponse(BaseModel):
    teacher_id: uuid.UUID
    full_name: str
    email: str | None = None

    model_config = ConfigDict(from_attributes=True)


# ===========================================================================
# ClassSchedule Schemas (Option A - Flat Response)
# ===========================================================================
class ClassScheduleBase(BaseModel):
    class_id: uuid.UUID = Field(..., description="UUID của lớp học")
    subject_id: uuid.UUID = Field(..., description="UUID của môn học/hoạt động")
    slot_id: uuid.UUID = Field(..., description="UUID của khung giờ")
    teacher_id: uuid.UUID | None = Field(None, description="UUID của giáo viên phụ trách (tùy chọn)")
    day_of_week: int = Field(
        ...,
        ge=2,
        le=7,
        description="Ngày trong tuần (2=Thứ 2, 3=Thứ 3, ..., 7=Thứ 7)",
    )
    activity_name: str | None = Field(None, description="Tiêu đề/Tên ngắn hoạt động")
    content: str | None = Field(None, description="Chi tiết nội dung hoạt động")
    room_name: str | None = Field(None, description="Phòng học hoặc vị trí")
    is_active: bool = Field(True, description="Trạng thái hoạt động")


class ClassScheduleCreate(ClassScheduleBase):
    pass


class ClassScheduleUpdate(BaseModel):
    subject_id: uuid.UUID | None = None
    slot_id: uuid.UUID | None = None
    teacher_id: uuid.UUID | None = None
    day_of_week: int | None = Field(None, ge=2, le=7)
    activity_name: str | None = None
    content: str | None = None
    room_name: str | None = None
    is_active: bool | None = None


class ClassScheduleBulkCreateItem(BaseModel):
    subject_id: uuid.UUID
    slot_id: uuid.UUID
    teacher_id: uuid.UUID | None = None
    day_of_week: int = Field(..., ge=2, le=7)
    activity_name: str | None = None
    content: str | None = None
    room_name: str | None = None


class ClassScheduleBulkCreateRequest(BaseModel):
    class_id: uuid.UUID
    schedules: list[ClassScheduleBulkCreateItem]


class ClassScheduleResponse(BaseModel):
    schedule_id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    slot_id: uuid.UUID
    teacher_id: uuid.UUID | None = None
    day_of_week: int
    activity_name: str | None = None
    content: str | None = None
    room_name: str | None = None
    is_active: bool

    time_slot: TimeSlotResponse | None = None
    subject: SubjectResponse | None = None
    teacher: TeacherSimpleResponse | None = None

    model_config = ConfigDict(from_attributes=True)
