"""
app/schemas/report.py
=====================
Pydantic schemas cho VoiceRecord và DailyReport API responses.

Tách biệt ORM models (SQLAlchemy) với API schemas (Pydantic) theo
nguyên tắc Clean Architecture — tránh expose trực tiếp ORM objects.
"""

from __future__ import annotations

import contextlib
import uuid
from datetime import date, datetime
from typing import Any

from app.models.report import VoiceRecordStatus
from pydantic import BaseModel, ConfigDict, Field, model_validator


# ===========================================================================
# VoiceRecord Schemas
# ===========================================================================
class VoiceRecordUploadResponse(BaseModel):
    """
    Response trả về sau khi upload audio thành công.

    Fields
    ------
    id / voice_record_id : UUID của VoiceRecord vừa tạo (dùng để poll status sau này)
    status               : Luôn là "pending" ngay sau upload
    """

    id: uuid.UUID = Field(
        ...,
        description="UUID của VoiceRecord vừa tạo",
        examples=["a3bb189e-8bf9-3888-9912-ace4e6543002"],
    )
    voice_record_id: uuid.UUID | None = Field(
        None,
        description="Alias UUID của VoiceRecord",
    )
    status: VoiceRecordStatus = Field(
        ...,
        description="Trạng thái xử lý audio. Luôn là 'pending' ngay sau khi upload.",
        examples=[VoiceRecordStatus.PENDING],
    )

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def sync_id(cls, data: Any) -> Any:
        if isinstance(data, dict):
            vid = data.get("id") or data.get("voice_record_id")
            if vid is not None:
                data["id"] = vid
                data["voice_record_id"] = vid
        return data


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
    voice_record_id: uuid.UUID | None = Field(
        None, description="Alias UUID của VoiceRecord"
    )
    status: VoiceRecordStatus = Field(..., description="Trạng thái xử lý audio")
    raw_transcript: str | None = Field(None, description="Bản dịch thô ban đầu từ AI")
    edited_transcript: str | None = Field(
        None, description="Bản dịch đã được giáo viên chỉnh sửa"
    )
    transcription: str | None = Field(
        None, description="Bản dịch hiệu lực (edited hoặc raw)"
    )
    error_message: str | None = Field(
        None, description="Thông báo lỗi chi tiết khi trạng thái là FAILED"
    )

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def sync_id(cls, data: Any) -> Any:
        if isinstance(data, dict):
            vid = data.get("id") or data.get("voice_record_id")
            if vid is not None:
                data["id"] = vid
                data["voice_record_id"] = vid
        return data


class ExtractionResult(BaseModel):
    """Kết quả trích xuất thực thể từ transcript.

    Mirror 1-1 với JSON column ``voice_record.extraction_result`` và với
    output của ``app.services.extraction_service.extract_from_transcript``.
    """

    meals: str | None = None
    sleeping: str | None = None
    health: str | None = None
    activities: str | None = None
    mood: str | None = None
    transcript: str | None = None


class DraftReportCreateRequest(BaseModel):
    """Payload khi tạo draft report từ VoiceRecord."""

    voice_record_id: uuid.UUID = Field(
        ...,
        description="UUID của VoiceRecord đã transcribe và extract",
    )
    teacher_id: uuid.UUID = Field(
        ...,
        description="UUID của giáo viên đang tạo báo cáo",
    )
    child_id: uuid.UUID | None = Field(
        None,
        description="UUID của học sinh (nếu voice_record chưa đính kèm child_id)",
    )
    extraction_result: dict[str, str | None] | None = Field(
        None,
        description="Dữ liệu trích xuất đã chỉnh sửa: {meals, sleeping, health, activities, mood}. Nếu null thì dùng extraction_result đã lưu trong DB.",
    )


class ManualReportCreateRequest(BaseModel):
    """Payload cho API tạo báo cáo thủ công (POST /api/teacher/reports/manual).

    Lưu ý về 6 field nội dung (``eating``, ``sleeping``, ``health``,
    ``activities``, ``mood``, ``teacher_note``)
    ---------------------------------------------------------------------
    ``daily_report`` KHÔNG có các cột này. Chúng là payload phẳng dùng ở tầng
    API và sẽ được chuyển thành các row ``activity_entry`` (hoặc ghi vào
    ``daily_report.summary_text``) trước khi persist::

        eating       -> ActivityCategory.MEAL      "Bữa ăn"
        sleeping     -> ActivityCategory.NAP       "Giấc ngủ"
        health       -> ActivityCategory.HEALTH    "Sức khỏe"
        activities   -> ActivityCategory.PLAY      "Hoạt động"
        mood         -> ActivityCategory.BEHAVIOR  "Tâm trạng"
        teacher_note -> ActivityCategory.OTHER     "Ghi chú giáo viên"
                       (+ daily_report.summary_text)

    Các field được giữ nguyên ở bước này để không phá vỡ contract hiện tại;
    sẽ được thay bằng ``activities: list[ActivityEntryInput]`` trong bước sau.
    """

    teacher_id: uuid.UUID = Field(..., description="UUID của giáo viên tạo báo cáo")
    child_id: uuid.UUID = Field(..., description="UUID của học sinh")
    eating: str | None = Field(None, description="Nội dung ăn uống")
    sleeping: str | None = Field(None, description="Nội dung giấc ngủ")
    health: str | None = Field(None, description="Nội dung sức khỏe")
    activities: str | None = Field(
        None, description="Nội dung hoạt động vui chơi/học tập"
    )
    mood: str | None = Field(None, description="Nội dung tâm trạng")
    teacher_note: str | None = Field(None, description="Ghi chú thêm của giáo viên")
    report_date: date | None = Field(None, description="Ngày của báo cáo (mặc định hôm nay)")


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

    daily_report_id: uuid.UUID | None = None
    report_id: uuid.UUID | None = None
    child_id: uuid.UUID | None = None
    teacher_id: uuid.UUID | None = None
    report_date: str
    status: str
    published_at: date | datetime | str | None = None
    activities: list[ActivityEntryResponse] = []

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def sync_id(cls, data: Any) -> Any:
        if isinstance(data, dict):
            rid = data.get("daily_report_id") or data.get("report_id")
            if rid is not None:
                data["daily_report_id"] = rid
                data["report_id"] = rid
        elif hasattr(data, "daily_report_id") or hasattr(data, "report_id"):
            rid = getattr(data, "daily_report_id", None) or getattr(
                data, "report_id", None
            )
            if rid is not None:
                with contextlib.suppress(AttributeError, TypeError):
                    data.daily_report_id = rid
                    data.report_id = rid
        return data


class SendReportResponse(BaseModel):
    """Result : send 1 report to parent"""

    daily_report_id: uuid.UUID = Field(..., description="UUID cua DailyReport")
    report_id: uuid.UUID | None = Field(None, description="Alias UUID cua DailyReport")
    status: str = Field(..., description="Trạng thái sau khi gửi")
    sent_at: datetime | None = Field(None, description="Thời gian cụ thể gửi (UTC)")
    child_id: uuid.UUID | None = Field(None, description="UUID cua tre")
    linked_parents: int = Field(0, description="Số ph liên kết với trẻ")
    targeted_devices: int = Field(
        0,
        description="Số thiết bị nhận thông báo (0 khi chưa cs FCM token )",
    )

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def sync_id(cls, data: Any) -> Any:
        if isinstance(data, dict):
            rid = data.get("daily_report_id") or data.get("report_id")
            if rid is not None:
                data["daily_report_id"] = rid
                data["report_id"] = rid
        return data


class SendAllRequest(BaseModel):
    """Payload cho POST /api/teacher/reports/send-all."""

    report_ids: list[uuid.UUID] | None = Field(
        None, description="Danh sách báo cáo cần gửi. Bỏ trống = bản nháp"
    )
    report_date: date | None = Field(
        None,
        description="Chỉ gửi report của ngày này (dùng khi empty trong report_ids)",
    )


class SendAllItemResult(BaseModel):
    """Kq cho từng báo cáo khi gửi hàng loạt."""

    daily_report_id: uuid.UUID
    report_id: uuid.UUID | None = None
    result: str = Field(..., description="sent | skipped | failed")
    detail: str | None = None

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def sync_id(cls, data: Any) -> Any:
        if isinstance(data, dict):
            rid = data.get("daily_report_id") or data.get("report_id")
            if rid is not None:
                data["daily_report_id"] = rid
                data["report_id"] = rid
        return data


class SendAllResponse(BaseModel):
    """Tổng kết kq gửi hàng loạt."""

    sent: int = 0
    skipped: int = 0
    failed: int = 0
    results: list[SendAllItemResult] = Field(default_factory=list)


# ===========================================================================
# Approve-Item Schemas (Auto-detect flow)
# ===========================================================================


class ApproveItemRequest(BaseModel):
    """
    Payload cho POST /api/teacher/reports/approve-item.

    Dùng cho flow Auto-detect: User bấm "Duyệt" trên 1 item trong Review screen
    → Backend tạo draft DailyReport NGAY.

    3 loại item:
        - "classwide": tạo N drafts (1 cho mỗi child trong class)
        - "child": tạo/update 1 draft cho child_id cụ thể
        - "unmatched": không tạo draft (user phải gán cho child trước qua "Gán" sheet)

    Fields
    ------
    voice_record_id : UUID của VoiceRecord (nguồn extraction)
    teacher_id      : UUID của giáo viên
    kind            : "classwide" | "child" | "unmatched"
    child_id        : UUID của child (REQUIRED khi kind="child")
    class_id        : UUID của lớp (REQUIRED khi kind="classwide" hoặc "unmatched")
    extraction      : (Optional) Override content nếu user đã sửa trong UI.
                       Nếu None → lấy từ voice_record.extraction_result
                       + child_extractions[child_id] (nếu kind="child")

    Ví dụ:
    {
        "voice_record_id": "...",
        "teacher_id": "...",
        "kind": "classwide",
        "class_id": "..."
    }
    """

    voice_record_id: uuid.UUID = Field(
        ..., description="UUID của VoiceRecord nguồn",
    )
    teacher_id: uuid.UUID = Field(
        ..., description="UUID của giáo viên đang duyệt",
    )
    kind: str = Field(
        ..., description="Loại item: 'classwide' | 'child' | 'unmatched'",
        pattern="^(classwide|child|unmatched)$",
    )
    child_id: uuid.UUID | None = Field(
        None, description="UUID của child (REQUIRED khi kind='child')",
    )
    class_id: uuid.UUID | None = Field(
        None,
        description="UUID của lớp (REQUIRED khi kind='classwide' hoặc 'unmatched')",
    )
    extraction: dict[str, str | None] | None = Field(
        None,
        description=(
            "Override content cho item. "
            "Nếu kind='classwide': dùng làm class_wide_extraction. "
            "Nếu kind='child': dùng làm child_override (merge với class-wide default)."
        ),
    )

    @model_validator(mode="after")
    def validate_required_fields(self) -> ApproveItemRequest:
        if self.kind == "child" and self.child_id is None:
            raise ValueError("child_id is required when kind='child'")
        if self.kind in ("classwide", "unmatched") and self.class_id is None:
            raise ValueError(f"class_id is required when kind='{self.kind}'")
        return self


class ApproveItemResponse(BaseModel):
    """Response cho POST /api/teacher/reports/approve-item."""

    kind: str = Field(..., description="Echo lại kind từ request")
    draft_report_ids: list[uuid.UUID] = Field(
        default_factory=list,
        description="Danh sách UUID của DailyReports vừa tạo/update",
    )
    count: int = Field(0, description="Số draft đã tạo")
    child_id_to_report_id: dict[str, str] | None = Field(
        None,
        description="Map child_id → report_id (chỉ có khi kind='classwide')",
    )
    merged_extraction: dict[str, str | None] | None = Field(
        None,
        description="Final content sau merge (chỉ có khi kind='child')",
    )
    note: str | None = Field(
        None,
        description="Note bổ sung (vd: cho unmatched → 'no draft created')",
    )


# ===========================================================================
# Send-Batch Schemas (Auto-detect flow)
# ===========================================================================


class SendBatchRequest(BaseModel):
    """
    Payload cho POST /api/teacher/reports/send-batch.

    Gửi nhiều draft reports trong 1 request (batch send).
    Khác send-all ở chỗ: gửi đúng các report_ids được chỉ định,
    không tự động filter theo teacher/date.

    Fields
    ------
    report_ids   : Danh sách UUID cần gửi. Nếu rỗng → dùng filter dưới
    class_id     : Filter theo lớp (nếu report_ids rỗng)
    report_date  : Filter theo ngày (nếu report_ids rỗng)
    teacher_id   : Filter theo giáo viên (nếu report_ids rỗng)
    """

    report_ids: list[uuid.UUID] | None = Field(
        None,
        description="Danh sách báo cáo cần gửi. Bỏ trống = filter theo class_id+date",
    )
    class_id: uuid.UUID | None = Field(
        None, description="Filter theo lớp (khi report_ids rỗng)",
    )
    report_date: date | None = Field(
        None, description="Filter theo ngày (khi report_ids rỗng)",
    )
    teacher_id: uuid.UUID | None = Field(
        None, description="Filter theo giáo viên (khi report_ids rỗng)",
    )

    @model_validator(mode="after")
    def validate_payload(self) -> SendBatchRequest:
        if not self.report_ids and not (self.class_id and self.report_date):
            raise ValueError(
                "Cần report_ids HOẶC (class_id + report_date)"
            )
        return self


class SendBatchItemResult(BaseModel):
    """Kết quả cho từng báo cáo khi gửi batch."""

    daily_report_id: uuid.UUID
    result: str = Field(..., description="sent | skipped | failed")
    detail: str | None = None

    model_config = ConfigDict(from_attributes=True)


class SendBatchResponse(BaseModel):
    """Tổng kết kết quả gửi batch."""

    sent: int = 0
    skipped: int = 0
    failed: int = 0
    results: list[SendBatchItemResult] = Field(default_factory=list)
