"""
app/api/teacher.py
==================
API endpoints dành cho Teacher.

TASK #57: POST /api/teacher/voice/upload
-----------------------------------------
Upload audio recording lên MinIO và tạo VoiceRecord trong DB.

Flow:
    1. Validate file extension (.m4a/.wav/.mp3/.webm) → 400 nếu sai
    2. Validate file size ≤ 25MB → 413 nếu vượt
    3. Lưu file vào temp path
    4. Chạy ffprobe để lấy audio_duration (giây)
    5. Upload lên MinIO → lấy audio_url
    6. Tạo VoiceRecord trong DB với status=PENDING
    7. Dispatch Celery task process_audio
    8. Trả về 201 { id, status }

MVP Note:
    Teacher auth bị bỏ qua — teacher_id được nhận trực tiếp từ form.
    TODO (sprint 2): Thay bằng Firebase JWT middleware.
"""

from __future__ import annotations

import json
import logging
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.storage import upload_audio_to_minio
from app.models.report import (
    ActivityCategory,
    ActivityEntry,
    DailyReport,
    DailyReportStatus,
    VoiceRecord,
    VoiceRecordStatus,
)
from app.schemas.report import (
    DraftReportCreateRequest,
    TranscriptUpdateRequest,
    VoiceRecordDetailResponse,
    VoiceRecordUploadResponse,
    SendAllItemResult,
    SendAllRequest,
    SendAllResponse,
    SendReportResponse,
)
from app.services.extraction_service import extract_from_transcript
from app.tasks.process_audio import process_audio_task
from app.services.notification_service import notification_service
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/teacher", tags=["teacher"])

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
ALLOWED_EXTENSIONS: set[str] = {".m4a", ".wav", ".mp3", ".webm"}
MAX_FILE_SIZE_BYTES: int = 25 * 1024 * 1024  # 25 MB

AUDIO_CONTENT_TYPES: dict[str, str] = {
    ".m4a": "audio/mp4",
    ".wav": "audio/wav",
    ".mp3": "audio/mpeg",
    ".webm": "audio/webm",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _extract_duration_ffprobe(file_path: str) -> float | None:
    """
    Dùng ffprobe để lấy thời lượng audio (giây).

    Returns None nếu ffprobe không có hoặc file lỗi.
    """
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "quiet",
                "-print_format",
                "json",
                "-show_format",
                file_path,
            ],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            raw = data.get("format", {}).get("duration")
            if raw is not None:
                return float(raw)
    except (
        subprocess.TimeoutExpired,
        FileNotFoundError,
        json.JSONDecodeError,
        ValueError,
    ):
        logger.warning("ffprobe failed for file: %s", file_path)
    return None


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@router.post(
    "/voice/upload",
    status_code=status.HTTP_201_CREATED,
    response_model=VoiceRecordUploadResponse,
    summary="Upload audio recording",
    description=(
        "Teacher upload một file audio. "
        "File được lưu vào MinIO, VoiceRecord được tạo với status=pending, "
        "và Celery task process_audio được kích hoạt để transcribe."
    ),
)
def upload_voice_record(
    file: UploadFile = File(..., description="Audio file (.m4a / .wav / .mp3 / .webm)"),  # noqa: B008
    teacher_id: uuid.UUID = Form(..., description="UUID của teacher đang upload"),  # noqa: B008
    class_id: uuid.UUID = Form(..., description="UUID của lớp học liên quan"),  # noqa: B008
    child_id: uuid.UUID | None = Form(None, description="UUID của child liên quan"),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> VoiceRecordUploadResponse:
    # ------------------------------------------------------------------
    # 1. Validate file extension
    # ------------------------------------------------------------------
    filename = file.filename or ""
    suffix = Path(filename).suffix.lower()

    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported audio format.",
        )

    # ------------------------------------------------------------------
    # 2. Read bytes & validate size
    # ------------------------------------------------------------------
    file_bytes = file.file.read()
    file_size = len(file_bytes)

    if file_size > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(
                f"File quá lớn: {file_size / 1024 / 1024:.1f} MB. "
                f"Giới hạn tối đa là 25 MB."
            ),
        )

    # ------------------------------------------------------------------
    # 3–5. Temp file → ffprobe → MinIO upload
    # ------------------------------------------------------------------
    tmp_path: str | None = None
    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(file_bytes)
            tmp_path = tmp.name

        # 4. ffprobe
        duration = _extract_duration_ffprobe(tmp_path)
        logger.info(
            "ffprobe result: teacher_id=%s duration=%s seconds", teacher_id, duration
        )

        # 5. Upload MinIO
        file_stem = Path(filename).stem or "recording"
        object_name = f"teacher_{teacher_id}_{file_stem}_{uuid.uuid4()}{suffix}"
        content_type = AUDIO_CONTENT_TYPES[suffix]
        audio_url = upload_audio_to_minio(
            file_path=tmp_path,
            object_name=object_name,
            content_type=content_type,
        )
        logger.info("Uploaded to MinIO: %s", audio_url)

    except Exception as exc:
        logger.exception("Upload failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Upload thất bại. Vui lòng thử lại.",
        ) from exc

    finally:
        # Xoá temp file dù có lỗi hay không
        if tmp_path:
            Path(tmp_path).unlink(missing_ok=True)

    # ------------------------------------------------------------------
    # 6. Tạo VoiceRecord trong DB
    # ------------------------------------------------------------------
    voice_record = VoiceRecord(
        teacher_id=teacher_id,
        child_id=child_id,
        audio_url=audio_url,
        audio_duration=duration,
        file_size_bytes=file_size,
        status=VoiceRecordStatus.PENDING,
    )
    db.add(voice_record)
    db.commit()
    db.refresh(voice_record)

    logger.info(
        "VoiceRecord created: id=%s teacher_id=%s",
        voice_record.voice_record_id,
        teacher_id,
    )

    # ------------------------------------------------------------------
    # 7. Dispatch Celery task
    # ------------------------------------------------------------------
    process_audio_task.delay(str(voice_record.voice_record_id))

    # ------------------------------------------------------------------
    # 8. Trả về 201
    # ------------------------------------------------------------------
    return VoiceRecordUploadResponse(
        id=voice_record.voice_record_id,
        status=voice_record.status.value,
    )


@router.get(
    "/voice/{voice_id}",
    response_model=VoiceRecordDetailResponse,
    summary="Get VoiceRecord detail & status",
    description="Trả về thông tin trạng thái (pending/processing/completed/failed) và các bản transcript.",
)
def get_voice_record(
    voice_id: uuid.UUID,
    teacher_id: uuid.UUID | None = None,
    db: Session = Depends(get_db),  # noqa: B008
) -> VoiceRecordDetailResponse:
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if teacher_id and voice_record.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this recording"
        )

    effective_transcript = (
        voice_record.edited_transcript
        or voice_record.raw_transcript
        or voice_record.transcription
    )

    return VoiceRecordDetailResponse(
        id=voice_record.voice_record_id,
        status=voice_record.status,
        raw_transcript=voice_record.raw_transcript or voice_record.transcription,
        edited_transcript=voice_record.edited_transcript,
        transcription=effective_transcript,
    )


@router.put(
    "/voice/{voice_id}/transcript",
    response_model=VoiceRecordDetailResponse,
    summary="Update transcript for a VoiceRecord",
    description="Lưu bản dịch đã chỉnh sửa vào edited_transcript mà không làm mất raw_transcript.",
)
def update_voice_transcript(
    voice_id: uuid.UUID,
    payload: TranscriptUpdateRequest,
    teacher_id: uuid.UUID | None = None,
    db: Session = Depends(get_db),  # noqa: B008
) -> VoiceRecordDetailResponse:
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if teacher_id and voice_record.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this recording"
        )

    voice_record.edited_transcript = payload.edited_transcript
    voice_record.transcription = (
        payload.edited_transcript or voice_record.raw_transcript
    )
    db.commit()
    db.refresh(voice_record)

    effective_transcript = (
        voice_record.edited_transcript
        or voice_record.raw_transcript
        or voice_record.transcription
    )

    return VoiceRecordDetailResponse(
        id=voice_record.voice_record_id,
        status=voice_record.status,
        raw_transcript=voice_record.raw_transcript or voice_record.transcription,
        edited_transcript=voice_record.edited_transcript,
        transcription=effective_transcript,
    )


@router.post("/voice/{voice_id}/extract")
def extract_voice(
    voice_id: uuid.UUID,
    teacher_id: uuid.UUID,  # TODO: replace with get_current_user when auth is ready
    db: Session = Depends(get_db),  # noqa: B008
):
    # 1. Lấy VoiceRecord từ DB
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    # 2. Check not found
    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    # 3. Verify ownership
    if voice_record.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this recording"
        )

    # 4. Check status == "done"
    if voice_record.status != VoiceRecordStatus.COMPLETED:
        raise HTTPException(status_code=400, detail="Transcript not ready")

    # 5. Lấy transcript (edited > raw)
    transcript = (
        voice_record.edited_transcript
        or voice_record.raw_transcript
        or voice_record.transcription
    )
    if not transcript:
        raise HTTPException(status_code=400, detail="No transcript found")

    # 6. Gọi extraction
    result = extract_from_transcript(transcript)

    # 7. Lưu vào DB
    voice_record.extraction_result = result
    db.commit()

    # 8. Return
    return {
        "voice_id": voice_id,
        "extraction": result,
    }

@router.post("/reports/draft")
def create_report_from_extraction(
    voice_id: uuid.UUID,
    teacher_id: uuid.UUID,
    payload: DraftReportCreateRequest | None = None,
    db: Session = Depends(get_db),  # noqa: B008
):
    # 1. Lấy VoiceRecord
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if voice_record.teacher_id != teacher_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    if not voice_record.child_id:
        raise HTTPException(status_code=400, detail="Please assign a child before creating report")

    if payload and payload.edited_extraction:
        result = payload.edited_extraction
        voice_record.extraction_result = result
    else:
        result = voice_record.extraction_result

    if not result:
        raise HTTPException(
            status_code=400,
            detail="No extraction result found. Please extract first.",
        )

    # 3. Tạo DailyReport
    today = datetime.now(timezone.utc).date()
    existing_report = db.query(DailyReport).filter(
        DailyReport.child_id == voice_record.child_id,
        DailyReport.report_date == today
    ).first()
    
    if existing_report:
        report = existing_report
        # Xoá các ActivityEntry cũ của báo cáo này trước khi ghi nhận lại
        db.query(ActivityEntry).filter(
            ActivityEntry.daily_report_id == report.daily_report_id
        ).delete()
    else:
        report = DailyReport(
            child_id=voice_record.child_id,
            teacher_id=teacher_id,
            voice_record_id=voice_id,
            report_date=today,
            status=DailyReportStatus.DRAFT,
        )
        db.add(report)
        db.flush()
    
    # 4. Map extraction → ActivityEntry
    mapping = [
        ("meals", "MEAL", "Bữa ăn"),
        ("sleeping", "NAP", "Giấc ngủ"),
        ("health", "HEALTH", "Sức khỏe"),
        ("activities", "PLAY", "Hoạt động"),
        ("mood", "BEHAVIOR", "Tâm trạng"),
    ]
    
    order = 0
    for key, category_str, title in mapping:
        value = result.get(key)
        if value:
            entry = ActivityEntry(
                daily_report_id=report.daily_report_id,
                category=ActivityCategory[category_str],
                title=title,
                description=value,
                entry_order=order,
            )
            db.add(entry)
            order += 1
    
    db.commit()
    
    return {
        "report_id": str(report.daily_report_id),
        "status": report.status.value
    }

SENT_STATUS = DailyReportStatus.SENT
reports_router = APIRouter(prefix="/api/reports", tags=["reports"])


class ReportAlreadySentError(HTTPException):
    """Bao cao da duoc gui truoc do.

    Ke thua HTTPException de endpoint don le tra ve 400 dung theo spec,
    dong thoi send-all bat rieng exception nay de dem vao `skipped`
    thay vi `failed` -> retry ca lo khong bi loi.
    """

    def __init__(self, report_id: uuid.UUID) -> None:
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Report {report_id} was already sent",
        )


def _send_one_report(
    report_id: uuid.UUID,
    teacher_id: uuid.UUID,
    db: Session,
) -> SendReportResponse:
    """Gửi một báo cáo. Dùng chung cho endpoint 
    lẻ + hàng loạt = luôn chung 1 bộ quy tắc."""

    # 1. 2 request đồng thời không thể gửi cùng 1 bản báo cáo.
    report = (
        db.query(DailyReport)
        .filter(DailyReport.daily_report_id == report_id)
        .with_for_update()
        .first()
    )

    if not report:
        db.rollback()
        raise HTTPException(status_code=404, detail="Report not found")

    # 2. Chủ sở hữu. Không sài `if teacher_id and ...`: bỏ qua check khi 
    # thiếu teacher_id
    if report.teacher_id != teacher_id:
        db.rollback()
        raise HTTPException(
            status_code=403, detail="Not authorized to send this report"
        )

    # 3. Đã gửi rồi -> 400 
    if report.status == SENT_STATUS:
        db.rollback()
        raise ReportAlreadySentError(report_id)

    # 4. Chỉ gửi được từ bản nháp
    if report.status != DailyReportStatus.DRAFT:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail=f"Report cannot be sent from status '{report.status.value}'",
        )

    # 5. Phải có trẻ (child_id nullable trong schema).
    if report.child_id is None:
        db.rollback()
        raise HTTPException(status_code=400, detail="Report has no child assigned")

    # 6. Phải có nội dung đã chốt (>= 1 ActivityEntry).
    if not report.activities:
        db.rollback()
        raise HTTPException(status_code=400, detail="Report has no finalized content")

    child = report.child
    child_name = (child.nickname or child.full_name) if child else "be"
    linked_parents = 1 if (child and child.parent_id) else 0

    # 7. Đổi trạng thái, save thời điểm gửi, commit TRƯỚC khi tb.
    report.status = SENT_STATUS
    report.sent_at = datetime.now(timezone.utc)
    report.published_at = report.sent_at.date()  # sync w frontend
    db.commit()
    db.refresh(report)

    logger.info(
        "[Send] report_id=%s teacher_id=%s sent_at=%s",
        report.daily_report_id,
        teacher_id,
        report.sent_at,
    )

    # 8. Thông báo SAU commit. Provider lỗi != revert lần gửi này.
    targeted_devices = 0
    try:
        targeted_devices = notification_service.notify_report_sent(
            report_id=str(report.daily_report_id),
            child_id=str(report.child_id),
            child_name=child_name,
            linked_parents=linked_parents,
        )
    except Exception:
        logger.exception(
            "[Send] Notification failed for report_id=%s - report stays '%s'",
            report.daily_report_id,
            report.status.value,
        )

    return SendReportResponse(
        report_id=report.daily_report_id,
        status=report.status.value,
        sent_at=report.sent_at,
        child_id=report.child_id,
        linked_parents=linked_parents,
        targeted_devices=targeted_devices,
    )


@reports_router.post(
    "/{report_id}/send",
    response_model=SendReportResponse,
    summary="Send a daily report to the parent",
    description=(
        "Đổi trạng thái báo cáo từ draft sang đã gửi, lưu thời điểm gửi, "
        "& kích hoạt tb cho phụ huynh sau khi commit."
    ),
)
def send_report(
    report_id: uuid.UUID,
    teacher_id: uuid.UUID,  # TODO: thay = get_current_user khi auth sẵn sàng
    db: Session = Depends(get_db),  # noqa: B008
) -> SendReportResponse:
    return _send_one_report(report_id, teacher_id, db)


@router.post(
    "/reports/send-all",
    response_model=SendAllResponse,
    summary="Send multiple draft reports",
    description=(
        "Send nhiều report trong 1 lần, mỗi báo cáo commit riêng "
        "Kết quả trả về cho từng báo cáo."
    ),
)
def send_all_reports(
    payload: SendAllRequest,
    teacher_id: uuid.UUID,  # TODO: thay = get_current_user khi auth sẵn sàng
    db: Session = Depends(get_db),  # noqa: B008
) -> SendAllResponse:
    # 1. Xac dinh danh sach bao cao can gui.
    if payload.report_ids:
        target_ids = list(dict.fromkeys(payload.report_ids))  # bo trung, giu thu tu
    else:
        query = db.query(DailyReport).filter(
            DailyReport.teacher_id == teacher_id,
            DailyReport.status == DailyReportStatus.DRAFT,
        )
        if payload.report_date:
            query = query.filter(DailyReport.report_date == payload.report_date)
        target_ids = [row.daily_report_id for row in query.all()]

    # 2. Gui tung bao cao, commit rieng tung cai (khong dung 1 transaction lon).
    results: list[SendAllItemResult] = []
    sent = skipped = failed = 0

    for target_id in target_ids:
        try:
            _send_one_report(target_id, teacher_id, db)
        except ReportAlreadySentError:
            # Retry ca lo: bao cao da gui khong phai loi, chi la bo qua.
            skipped += 1
            results.append(
                SendAllItemResult(
                    report_id=target_id, result="skipped", detail="Already sent"
                )
            )
        except HTTPException as exc:
            failed += 1
            results.append(
                SendAllItemResult(
                    report_id=target_id, result="failed", detail=str(exc.detail)
                )
            )
        except Exception:
            db.rollback()
            logger.exception("[SendAll] Unexpected failure report_id=%s", target_id)
            failed += 1
            results.append(
                SendAllItemResult(
                    report_id=target_id, result="failed", detail="Unexpected error"
                )
            )
        else:
            sent += 1
            results.append(SendAllItemResult(report_id=target_id, result="sent"))

    return SendAllResponse(sent=sent, skipped=skipped, failed=failed, results=results)