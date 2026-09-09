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
    edited_transcript: str | None = Field(None, description="Bản dịch đã được giáo viên chỉnh sửa")
    transcription: str | None = Field(None, description="Bản dịch hiệu lực (edited hoặc raw)")

    model_config = ConfigDict(from_attributes=True)


