"""
app/schemas/schedule.py
========================
Pydantic schemas cho TimeSlot, Subject, và ClassSchedule API requests & responses.
"""

from __future__ import annotations

import uuid

from typing import Any

from pydantic import BaseModel, ConfigDict, Field, model_validator


def _validate_slot_or_custom_times(
    slot_id: uuid.UUID | None,
    custom_start_time: str | None,
    custom_end_time: str | None,
) -> None:
    """Validate that either slot_id or a complete custom time range is supplied."""
    has_start = bool(custom_start_time and custom_start_time.strip())
    has_end = bool(custom_end_time and custom_end_time.strip())
    if has_start != has_end:
        raise ValueError("Cần cung cấp đầy đủ custom_start_time và custom_end_time.")
    if slot_id is None and not (has_start and has_end):
        raise ValueError(
            "Cần chọn khung giờ (slot_id) hoặc nhập giờ tùy chỉnh (custom_start_time, custom_end_time)."
        )


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
    slot_id: uuid.UUID | None = Field(
        None, description="UUID của khung giờ chuẩn (để trống nếu dùng giờ tùy chỉnh)"
    )
    custom_start_time: str | None = Field(
        None, description="Giờ bắt đầu tùy chỉnh (HH:MM) khi không gắn time_slot"
    )
    custom_end_time: str | None = Field(
        None, description="Giờ kết thúc tùy chỉnh (HH:MM) khi không gắn time_slot"
    )
    teacher_id: uuid.UUID | None = Field(
        None, description="UUID của giáo viên phụ trách (tùy chọn)"
    )
    day_of_week: int = Field(
        ...,
        ge=2,
        le=6,
        description="Ngày trong tuần (2=Thứ 2, 3=Thứ 3, ..., 6=Thứ 6)",
    )
    activity_name: str | None = Field(None, description="Tiêu đề/Tên ngắn hoạt động")
    content: str | None = Field(None, description="Chi tiết nội dung hoạt động")
    room_name: str | None = Field(None, description="Phòng học hoặc vị trí")
    is_active: bool = Field(True, description="Trạng thái hoạt động")

    @model_validator(mode="after")
    def _check_time_selection(self) -> "ClassScheduleBase":
        _validate_slot_or_custom_times(
            self.slot_id, self.custom_start_time, self.custom_end_time
        )
        return self


class ClassScheduleCreate(ClassScheduleBase):
    pass


class ClassScheduleUpdate(BaseModel):
    subject_id: uuid.UUID | None = None
    slot_id: uuid.UUID | None = None
    custom_start_time: str | None = None
    custom_end_time: str | None = None
    teacher_id: uuid.UUID | None = None
    day_of_week: int | None = Field(None, ge=2, le=6)
    activity_name: str | None = None
    content: str | None = None
    room_name: str | None = None
    is_active: bool | None = None


class ClassScheduleBulkCreateItem(BaseModel):
    subject_id: uuid.UUID
    slot_id: uuid.UUID | None = None
    custom_start_time: str | None = None
    custom_end_time: str | None = None
    teacher_id: uuid.UUID | None = None
    day_of_week: int = Field(..., ge=2, le=6)
    activity_name: str | None = None
    content: str | None = None
    room_name: str | None = None

    @model_validator(mode="after")
    def _check_time_selection(self) -> "ClassScheduleBulkCreateItem":
        _validate_slot_or_custom_times(
            self.slot_id, self.custom_start_time, self.custom_end_time
        )
        return self


class ClassScheduleBulkCreateRequest(BaseModel):
    class_id: uuid.UUID
    schedules: list[ClassScheduleBulkCreateItem]


class ClassScheduleResponse(BaseModel):
    schedule_id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    slot_id: uuid.UUID | None = None
    custom_start_time: str | None = None
    custom_end_time: str | None = None
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

    @model_validator(mode="before")
    @classmethod
    def _populate_virtual_custom_time_slot(cls, data: Any) -> Any:
        if isinstance(data, dict):
            slot_id = data.get("slot_id")
            time_slot = data.get("time_slot")
            custom_start = data.get("custom_start_time")
            custom_end = data.get("custom_end_time")
            schedule_id = data.get("schedule_id")
            if (
                slot_id is None
                and time_slot is None
                and isinstance(custom_start, str)
                and custom_start
                and isinstance(custom_end, str)
                and custom_end
                and schedule_id is not None
            ):
                return {
                    **data,
                    "time_slot": {
                        "slot_id": schedule_id,
                        "name": f"{custom_start} - {custom_end}",
                        "start_time": custom_start,
                        "end_time": custom_end,
                    },
                }
            return data

        custom_start = getattr(data, "custom_start_time", None)
        custom_end = getattr(data, "custom_end_time", None)
        if not isinstance(custom_start, str | type(None)):
            custom_start = None
        if not isinstance(custom_end, str | type(None)):
            custom_end = None

        slot_id = getattr(data, "slot_id", None)
        time_slot = getattr(data, "time_slot", None)
        schedule_id = getattr(data, "schedule_id", None)

        if (
            slot_id is None
            and time_slot is None
            and custom_start
            and custom_end
            and schedule_id is not None
        ):
            time_slot = {
                "slot_id": schedule_id,
                "name": f"{custom_start} - {custom_end}",
                "start_time": custom_start,
                "end_time": custom_end,
            }

        return {
            "schedule_id": schedule_id,
            "class_id": getattr(data, "class_id", None),
            "subject_id": getattr(data, "subject_id", None),
            "slot_id": slot_id,
            "custom_start_time": custom_start,
            "custom_end_time": custom_end,
            "teacher_id": getattr(data, "teacher_id", None),
            "day_of_week": getattr(data, "day_of_week", None),
            "activity_name": getattr(data, "activity_name", None),
            "content": getattr(data, "content", None),
            "room_name": getattr(data, "room_name", None),
            "is_active": getattr(data, "is_active", True),
            "time_slot": time_slot,
            "subject": getattr(data, "subject", None),
            "teacher": getattr(data, "teacher", None),
        }
