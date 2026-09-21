"""
app/schemas/report.py
=====================
Pydantic schemas cho VoiceRecord và DailyReport API responses.

Tách biệt ORM models (SQLAlchemy) với API schemas (Pydantic) theo
nguyên tắc Clean Architecture — tránh expose trực tiếp ORM objects.
"""

from __future__ import annotations

import uuid

from app.models.report import VoiceRecordStatus
from pydantic import BaseModel, ConfigDict, Field
from datetime import date, datetime
# ===========================================================================
# VoiceRecord Schemas
# ===========================================================================


class VoiceRecordUploadResponse(BaseModel):
    """
    Response trả về sau khi upload audio thành công.

    Fields
    ------
    id     : UUID của VoiceRecord vừa tạo (dùng để poll status sau này)
    status : Luôn là "pending" ngay sau upload
    """

    id: uuid.UUID = Field(
        ...,
        description="UUID của VoiceRecord vừa tạo",
        examples=["a3bb189e-8bf9-3888-9912-ace4e6543002"],
    )
    status: VoiceRecordStatus = Field(
        ...,
        description="Trạng thái xử lý audio. Luôn là 'pending' ngay sau khi upload.",
        examples=[VoiceRecordStatus.PENDING],
    )

    model_config = ConfigDict(from_attributes=True)


class TranscriptUpdateRequest(BaseModel):
    """Payload gửi lên từ Flutter UI khi giáo viên chỉnh sửa transcript."""

    edited_transcript: str = Field(
        ...,
        min_length=1,
        description="Nội dung transcript đã chỉnh sửa của giáo viên",
        examples=["Bé ăn ngoan, ngủ 1 tiếng rưỡi."],
    )


class VoiceRecordDetailResponse(BaseModel):
    """Response trả về chi tiết VoiceRecord bao gồm cả raw và edited transcript."""

    id: uuid.UUID = Field(..., description="UUID của VoiceRecord")
    status: VoiceRecordStatus = Field(..., description="Trạng thái xử lý audio")
    raw_transcript: str | None = Field(None, description="Bản dịch thô ban đầu từ AI")
    edited_transcript: str | None = Field(
        None, description="Bản dịch đã được giáo viên chỉnh sửa"
    )
    transcription: str | None = Field(
        None, description="Bản dịch hiệu lực (edited hoặc raw)"
    )

    model_config = ConfigDict(from_attributes=True)


class DraftReportCreateRequest(BaseModel):
    """Payload tuỳ chọn khi tạo draft report với dữ liệu trích xuất đã chỉnh sửa."""

    edited_extraction: dict[str, str | None] | None = Field(
        None,
        description="Dữ liệu trích xuất đã chỉnh sửa của giáo viên: {meals, sleeping, health, activities, mood}",
    )

class SendReportResponse(BaseModel):
    """Result : send 1 report to parent"""

    report_id: uuid.UUID = Field(..., description="UUID của DailyReport")
    status: str = Field(..., description="Trạng thái sau khi gửi")
    sent_at: datetime | None = Field(None, description="Thời gian gửi cụ thể (UTC)")
    child_id: uuid.UUID | None = Field(None, description="UUID cua tre")
    linked_parents: int = Field(0, description="Số lượng phụ huynh liên kết với trẻ")
    targeted_devices: int = Field(
        0,
        description="Số device nhận tb (0 khi chưa cs FCM token )",
    )


class SendAllRequest(BaseModel):
    """Payload cho POST /api/teacher/reports/send-all."""

    report_ids: list[uuid.UUID] | None = Field(
        None, description="Danh sách báo cáo cần gửi. Bỏ trống = bản nháp"
    )
    report_date: date | None = Field(
        None, description="Chỉ gửi báo cáo của ngày này (dùng khi bỏ trống report_ids)"
    )


class SendAllItemResult(BaseModel):
    """Kq cho từng báo cáo khi gửi hàng loạt."""

    report_id: uuid.UUID
    result: str = Field(..., description="sent | skipped | failed")
    detail: str | None = None


class SendAllResponse(BaseModel):
    """Tổng kết kq gửi hàng loạt."""

    sent: int = 0
    skipped: int = 0
    failed: int = 0
    results: list[SendAllItemResult] = Field(default_factory=list)

