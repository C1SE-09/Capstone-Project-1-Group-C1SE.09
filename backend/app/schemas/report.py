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

