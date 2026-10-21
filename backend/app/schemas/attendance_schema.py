"""
backend/app/schemas/attendance.py
=================================
Pydantic Schemas cho API Điểm danh.
Độc lập, không sửa đổi schema của các module khác.
"""

from __future__ import annotations

import uuid
from datetime import date, time
from pydantic import BaseModel, ConfigDict, Field

from app.models.attendance import AttendanceStatus

# ---------------------------------------------------------------------------
# 1. Input Schemas (Dữ liệu gửi lên khi điểm danh)
# 

class AttendanceItemCreate(BaseModel):
    """Thông tin điểm danh của 1 học sinh"""
    child_id: uuid.UUID
    status: AttendanceStatus = Field(
        default=AttendanceStatus.PRESENT,
        description="Trạng thái present (có mặt), absent (vắng mặt), late (đến muộn)"
    )
    check_in_time: time | None = Field(
        default=None,
        description="Giờ vào lớp thực tế (dùng khi trẻ được bố mẹ đưa đến muộn)"
    )
    note: str | None = Field(
        default=None,
        max_length=255,
        description="Ghi chú nhanh của giáo viên"
    )

class AttendanceBatchSaveRequest(BaseModel):
    """Payload lưu điểm danh cả lớp"""
    class_id: uuid.UUID
    date: date
    records: list[AttendanceItemCreate] = Field(
        ...,
        description="Danh sách điểm danh của các bé trong lớp"
    )

# ---------------------------------------------------------------------------
# 2. Output Schemas (Dữ liệu trả về cho App Flutter)
# ---------------------------------------------------------------------------

class ChildAttendanceResponse(BaseModel):
    """Chi tiết điểm danh từng bé hiển thị trên giao diện"""
    model_config = ConfigDict(from_attributes=True)

    child_id: uuid.UUID
    full_name: str
    nickname: str | None = None
    avatar_url: str | None = None
    status: AttendanceStatus
    check_in_time: time | None = None
    note: str | None = None

class ClassAttendanceSummaryResponse(BaseModel):
    """Bảng điểm danh đầy đủ của lớp kèm thống kê sĩ số"""
    class_id: uuid.UUID
    date: date
    total_children: int
    present_count: int
    absent_count: int
    late_count: int
    children: list[ChildAttendanceResponse]

class AttendanceBatchSaveResponse(BaseModel):
    """Kết quả phản hồi sau khi lưu"""
    success: bool
    message: str
    saved_count: int

class AttendanceNotifyAbsentRequest(BaseModel):
    "Yêu cầu gửi thông báo cho phụ huynh các bé vắng"
    class_id: uuid.UUID
    date: date
    #Nếu danh sách rỗng, hệ thống sẽ tự động quét toàn bộ các bé vắng trong ngày của lớp
    child_ids: list[uuid.UUID] | None = Field(
        default=None,
        description="Danh sách child_id cụ thể cần gửi"
    )

class AttendanceNotifyAbsentResponse(BaseModel):
    "Kết quả phản hồi của API thông báo"                        
    success: bool
    message: str
    target_count: int