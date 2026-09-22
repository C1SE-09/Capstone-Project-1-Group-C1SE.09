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
    """Payload khi tạo draft report từ VoiceRecord."""

    voice_id: uuid.UUID = Field(
        ...,
        description="UUID của VoiceRecord đã transcribe và extract",
    )
    teacher_id: uuid.UUID = Field(
        ...,
        description="UUID của giáo viên đang tạo báo cáo",
    )
    edited_extraction: dict[str, str | None] | None = Field(
        None,
        description="Dữ liệu trích xuất đã chỉnh sửa: {meals, sleeping, health, activities, mood}. Nếu null thì dùng extraction_result đã lưu trong DB.",
    )


class ActivityEntryResponse(BaseModel):
    """Response cho một hoạt động trong báo cáo."""

    activity_entry_id: uuid.UUID
    category: str
    title: str
    description: str | None = None
    entry_order: int

    model_config = ConfigDict(from_attributes=True)


class DailyReportDetailResponse(BaseModel):
    """Response chi tiết một DailyReport bao gồm danh sách ActivityEntry."""

    report_id: uuid.UUID
    child_id: uuid.UUID | None = None
    teacher_id: uuid.UUID | None = None
    report_date: str
    status: str
    published_at: str | None = None
    activities: list[ActivityEntryResponse] = []

    model_config = ConfigDict(from_attributes=True)

class SendReportResponse(BaseModel):
    """Result : send 1 report to parent"""

    report_id: uuid.UUID = Field(..., description="UUID cß╗ºa DailyReport")
    status: str = Field(..., description="Trß║íng th├íi sau khi gß╗¡i")
    sent_at: datetime | None = Field(None, description="Thß╗¥i gian gß╗¡i cß╗Ñ thß╗â (UTC)")
    child_id: uuid.UUID | None = Field(None, description="UUID cua tre")
    linked_parents: int = Field(0, description="Sß╗æ l╞░ß╗úng phß╗Ñ huynh li├¬n kß║┐t vß╗¢i trß║╗")
    targeted_devices: int = Field(
        0,
        description="Sß╗æ device nhß║¡n tb (0 khi ch╞░a cs FCM token )",
    )


class SendAllRequest(BaseModel):
    """Payload cho POST /api/teacher/reports/send-all."""

    report_ids: list[uuid.UUID] | None = Field(
        None, description="Danh s├ích b├ío c├ío cß║ºn gß╗¡i. Bß╗Å trß╗æng = bß║ún nh├íp"
    )
    report_date: date | None = Field(
        None, description="Chß╗ë gß╗¡i b├ío c├ío cß╗ºa ng├áy n├áy (d├╣ng khi bß╗Å trß╗æng report_ids)"
    )


class SendAllItemResult(BaseModel):
    """Kq cho tß╗½ng b├ío c├ío khi gß╗¡i h├áng loß║ít."""

    report_id: uuid.UUID
    result: str = Field(..., description="sent | skipped | failed")
    detail: str | None = None


class SendAllResponse(BaseModel):
    """Tß╗òng kß║┐t kq gß╗¡i h├áng loß║ít."""

    sent: int = 0
    skipped: int = 0
    failed: int = 0
    results: list[SendAllItemResult] = Field(default_factory=list)

