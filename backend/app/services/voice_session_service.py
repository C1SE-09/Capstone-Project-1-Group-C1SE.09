"""
app/services/voice_session_service.py
=====================================
Service cho "phiên ghi âm nhiều bản" (multi-clip recording session).

User story
----------
Giáo viên mầm non ghi âm nhiều lần trong ngày thay vì 1 lần cuối ngày.
Mỗi lần ghi tạo 1 bản ghi (row ``VoiceRecord``) hiển thị như Messenger
(nút nghe / nút xoá). Khi bấm "Gửi" 1 lần → hệ thống:

1. Gộp transcript của N bản thành 1 text duy nhất (nối bằng newline).
2. Chạy NLP **1 lần** trên text gộp đó (``extract_multi_person``).

Vì sao gộp transcript thay vì gộp kết quả extract?
----------------------------------------------------
``extract_multi_person`` tự làm 3 việc: tách segment → match tên bé →
gom vào 3 bucket (class-wide / child-specific / unmatched). Nếu ta extract
từng bản riêng rồi ghép kết quả, ta phải tự viết lại logic merge và
dễ mất dữ liệu (bucket ``child_extractions`` dùng semantics REPLACE —
bản sau đè bản trước). Gộp transcript trước rồi gọi 1 lần giữ nguyên
toàn bộ semantics sẵn có.

Luồng dữ liệu
--------------
    Ghi âm bản 1 ──upload──▶ VoiceRecord(1) ──Celery STT──▶ raw_transcript₁
    Ghi âm bản 2 ──upload──▶ VoiceRecord(2) ──Celery STT──▶ raw_transcript₂
    Ghi âm bản N ──upload──▶ VoiceRecord(N) ──Celery STT──▶ raw_transcriptₙ
                              │
                              └─ cùng session_id ─▶ VoiceRecordingSession
                                        │
                     bấm "Gửi" ──────┴──▶ merge_transcripts() ─▶ 1 text
                                                 │
                                                 └──▶ analyze → extraction
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timezone

from sqlalchemy.orm import Session

from app.config import get_today
from app.core.storage import delete_audio_from_minio
from app.models.child import Child
from app.models.report import (
    VoiceRecordingSession,
    VoiceRecordingSessionStatus,
    VoiceRecord,
    VoiceRecordScope,
    VoiceRecordStatus,
)
from app.models.user import Teacher

logger = logging.getLogger(__name__)


# ===========================================================================
# Constants
# ===========================================================================

# Dấu phân cách giữa các bản ghi khi gộp transcript: 1 dấu cách, không xuống hàng.
TRANSCRIPT_SEPARATOR = " "

# Số ký tự tối đa cho transcript gộp.
#
# Model NLP (`extract_multi_person`) chạy PER-SEGMENT nên độ dài tổng
# không làm vỡ model, nhưng endpoint /analyze vẫn validate 1 lần trên
# transcript gộp → cần trần để tránh payload quá lớn.
MAX_MERGED_TRANSCRIPT_CHARS = 100_000


# ===========================================================================
# Helpers
# ===========================================================================


def _session_query(db: Session, session_id: uuid.UUID):
    """Query session kèm eager-load các quan hệ cần thiết."""
    return (
        db.query(VoiceRecordingSession)
        .filter(VoiceRecordingSession.session_id == session_id)
        .first()
    )


def _validate_session_ownership(
    session: VoiceRecordingSession,
    teacher_id: uuid.UUID | None,
) -> None:
    """
    Kiểm tra giáo viên có quyền với phiên này không.

    Raises:
        PermissionError: nếu teacher khác sở hữu phiên.
    """
    if teacher_id is None:
        return
    # Legacy/session không gắn teacher → cho qua (MVP không có auth thật).
    if session.teacher_id is None:
        return
    if session.teacher_id != teacher_id:
        raise PermissionError("Not authorized to access this recording session")


def sorted_clips(session: VoiceRecordingSession) -> list[VoiceRecord]:
    """
    Trả về các bản ghi của phiên, sắp xếp theo đúng thứ tự ghi.

    Ưu tiên ``clip_order`` (được gán khi upload) vì nhiều bản ghi có thể
    trùng ``created_at`` (cùng transaction / cùng giây) → sắp xếp theo
    timestamp sẽ không ổn định.

    Fallback về ``created_at`` cho các bản ghi cũ chưa có ``clip_order``.
    """
    return sorted(
        session.voice_records,
        key=lambda vr: (
            vr.clip_order if vr.clip_order is not None else 10**9,
            vr.created_at or datetime.min.replace(tzinfo=timezone.utc),
            str(vr.voice_record_id),
        ),
    )


# ===========================================================================
# Public API
# ===========================================================================


def create_session(
    db: Session,
    teacher_id: uuid.UUID | None,
    class_id: uuid.UUID | None,
    child_id: uuid.UUID | None = None,
    scope: VoiceRecordScope = VoiceRecordScope.WHOLE_CLASS,
    recorded_at: date | None = None,
) -> VoiceRecordingSession:
    """
    Tạo 1 phiên ghi âm mới.

    Args:
        db: SQLAlchemy session
        teacher_id: Giáo viên sở hữu phiên
        class_id: Lớp của phiên
        child_id: Bé (chỉ khi scope = single_child)
        scope: single_child hay whole_class
        recorded_at: Ngày ghi âm (mặc định = hôm nay theo giờ VN)

    Returns:
        VoiceRecordingSession vừa tạo (đã flush, chưa commit).
    """
    session = VoiceRecordingSession(
        teacher_id=teacher_id,
        class_id=class_id,
        child_id=child_id,
        scope=scope,
        recorded_at=recorded_at or get_today(),
        status=VoiceRecordingSessionStatus.ACTIVE,
    )
    db.add(session)
    db.flush()
    logger.info(
        "[VoiceSession] Created session=%s teacher=%s class=%s scope=%s",
        session.session_id,
        teacher_id,
        class_id,
        scope.value,
    )
    return session


def get_or_create_active_session(
    db: Session,
    teacher_id: uuid.UUID | None,
    class_id: uuid.UUID | None,
    child_id: uuid.UUID | None = None,
    scope: VoiceRecordScope = VoiceRecordScope.WHOLE_CLASS,
    recorded_at: date | None = None,
) -> VoiceRecordingSession:
    """
    Lấy phiên ACTIVE của (teacher, class, ngày) nếu có, không thì tạo mới.

    Cho phép app mở lại phiên ghi âm cũ trong cùng ngày (ví dụ cô ấy
    đóng app rồi mở lại) mà không tạo phiên trùng.
    """
    target_date = recorded_at or get_today()

    query = db.query(VoiceRecordingSession).filter(
        VoiceRecordingSession.status == VoiceRecordingSessionStatus.ACTIVE,
        VoiceRecordingSession.recorded_at == target_date,
    )
    if teacher_id is not None:
        query = query.filter(VoiceRecordingSession.teacher_id == teacher_id)
    if class_id is not None:
        query = query.filter(VoiceRecordingSession.class_id == class_id)

    existing = query.order_by(VoiceRecordingSession.created_at.desc()).first()
    if existing is not None:
        return existing

    return create_session(
        db=db,
        teacher_id=teacher_id,
        class_id=class_id,
        child_id=child_id,
        scope=scope,
        recorded_at=target_date,
    )


def attach_clip_to_session(
    db: Session,
    voice_record: VoiceRecord,
    session: VoiceRecordingSession,
) -> VoiceRecord:
    """
    Gắn 1 bản ghi vào phiên và gán thứ tự (clip_order).

    ``clip_order`` = max(clip_order hiện có) + 1 (0, 1, 2...). Nhờ vậy thứ tự
    gộp transcript luôn khớp với thứ tự cô giáo viên ghi, kể cả khi nhiều
    bản có cùng ``created_at``.

    Dùng ``max + 1`` chứ không phải ``len()`` vì sau khi xoá giữa phiên,
    ``len()`` có thể sinh trùng ``clip_order`` với bản đang tồn tại.
    """
    existing_orders = [
        c.clip_order for c in session.voice_records if c.clip_order is not None
    ]
    next_order = (max(existing_orders) + 1) if existing_orders else 0

    voice_record.session_id = session.session_id
    voice_record.clip_order = next_order
    db.flush()
    logger.info(
        "[VoiceSession] Attached clip=%s to session=%s (order=%s)",
        voice_record.voice_record_id,
        session.session_id,
        next_order,
    )
    return voice_record


def merge_transcripts(session: VoiceRecordingSession) -> str:
    """
    Gộp transcript của tất cả bản ghi trong phiên thành 1 text.

    Chỉ lấy transcript đã STT xong (``status = COMPLETED``) và không rỗng.
    Bản ghi lỗi (FAILED) bị bỏ qua — không chặn cả phiên.

    Returns:
        Text gộp (các bản nối bằng newline). Trả về chuỗi rỗng nếu không
        bản nào có transcript.
    """
    parts: list[str] = []

    for clip in sorted_clips(session):
        if clip.status != VoiceRecordStatus.COMPLETED:
            logger.warning(
                "[VoiceSession] Bỏ qua clip=%s (status=%s) khi gộp transcript",
                clip.voice_record_id,
                clip.status.value,
            )
            continue

        text = (clip.edited_transcript or clip.raw_transcript or "").strip()
        # Loại bỏ dấu chấm ở cuối đoạn nếu có
        text = text.rstrip(".").strip()
        if not text:
            continue

        parts.append(text)

    if not parts:
        return ""

    merged = TRANSCRIPT_SEPARATOR.join(parts)

    if len(merged) > MAX_MERGED_TRANSCRIPT_CHARS:
        logger.warning(
            "[VoiceSession] Transcript gộp bị cắt còn %d ký tự (gốc %d)",
            MAX_MERGED_TRANSCRIPT_CHARS,
            len(merged),
        )
        merged = merged[:MAX_MERGED_TRANSCRIPT_CHARS]

    return merged


def mark_session_merged(
    db: Session,
    session: VoiceRecordingSession,
    merged_transcript: str,
    representative_voice_record_id: uuid.UUID | None,
) -> VoiceRecordingSession:
    """
    Đánh dấu phiên đã gộp + lưu transcript gộp + trỏ bản ghi đại diện.

    Args:
        db: SQLAlchemy session
        session: Phiên cần cập nhật
        merged_transcript: Text đã gộp (đã lưu vào DB để truy vết)
        representative_voice_record_id: Bản ghi đại diện (nơi lưu
            ``extraction_result`` sau khi phân tích). Thường là bản đầu tiên.

    Returns:
        session đã cập nhật.
    """
    session.merged_transcript = merged_transcript
    session.representative_voice_record_id = representative_voice_record_id
    session.status = VoiceRecordingSessionStatus.MERGED
    db.flush()
    logger.info(
        "[VoiceSession] Merged session=%s clips=%d representative=%s",
        session.session_id,
        len(session.voice_records),
        representative_voice_record_id,
    )
    return session


def delete_clip(
    db: Session,
    clip_id: uuid.UUID,
    teacher_id: uuid.UUID | None,
) -> bool:
    """
    Xoá 1 bản ghi âm khỏi phiên (nút X trên thanh ghi âm Messenger-style).

    Xoá cả row trong DB lẫn file audio trên MinIO.

    Args:
        db: SQLAlchemy session
        clip_id: UUID của VoiceRecord cần xoá
        teacher_id: Giáo viên sở hữu (để kiểm tra quyền)

    Returns:
        True nếu đã xoá, False nếu không tìm thấy.

    Raises:
        PermissionError: nếu teacher khác sở hữu bản ghi.
    """
    clip = db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == clip_id).first()
    if clip is None:
        return False

    if teacher_id is not None and clip.teacher_id is not None:
        if clip.teacher_id != teacher_id:
            raise PermissionError("Not authorized to delete this recording")

    # Nếu bản ghi đại diện bị xoá → chọn bản còn lại đầu tiên làm đại diện.
    if clip.session_id is not None:
        session = _session_query(db, clip.session_id)
        if session is not None:
            if session.representative_voice_record_id == clip.voice_record_id:
                session.representative_voice_record_id = None

    # Xoá file audio trên MinIO (best-effort, lỗi storage không chặn xoá DB).
    if clip.audio_url:
        try:
            delete_audio_from_minio(clip.audio_url)
        except Exception:
            logger.exception(
                "[VoiceSession] Không xoá được file MinIO cho clip=%s",
                clip.voice_record_id,
            )

    db.delete(clip)
    db.flush()
    logger.info("[VoiceSession] Deleted clip=%s", clip_id)
    return True


def discard_session(
    db: Session,
    session_id: uuid.UUID,
    teacher_id: uuid.UUID | None,
) -> bool:
    """
    Huỷ 1 phiên ghi âm (đánh dấu discarded, KHÔNG xoá các bản ghi).

    Các bản ghi vẫn giữ lại để giáo viên tham khảo/audit.

    Returns:
        True nếu đã huỷ, False nếu không tìm thấy phiên.
    """
    session = _session_query(db, session_id)
    if session is None:
        return False

    _validate_session_ownership(session, teacher_id)

    session.status = VoiceRecordingSessionStatus.DISCARDED
    db.flush()
    logger.info("[VoiceSession] Discarded session=%s", session_id)
    return True


def list_sessions(
    db: Session,
    teacher_id: uuid.UUID | None,
    class_id: uuid.UUID | None = None,
    recorded_at: date | None = None,
    status: VoiceRecordingSessionStatus | None = None,
) -> list[VoiceRecordingSession]:
    """
    Liệt kê các phiên ghi âm (dùng để app mở lại phiên cũ trong ngày).

    Args:
        db: SQLAlchemy session
        teacher_id: Giáo viên (bắt buộc lọc nếu có)
        class_id: Lọc theo lớp
        recorded_at: Lọc theo ngày
        status: Lọc theo trạng thái (mặc định không lọc)
    """
    query = db.query(VoiceRecordingSession)

    if teacher_id is not None:
        query = query.filter(VoiceRecordingSession.teacher_id == teacher_id)
    if class_id is not None:
        query = query.filter(VoiceRecordingSession.class_id == class_id)
    if recorded_at is not None:
        query = query.filter(VoiceRecordingSession.recorded_at == recorded_at)
    if status is not None:
        query = query.filter(VoiceRecordingSession.status == status)

    return query.order_by(VoiceRecordingSession.created_at.desc()).all()


def resolve_teacher_id(db: Session, teacher_id: uuid.UUID | None) -> uuid.UUID | None:
    """
    Resolve teacher_id hợp lệ.

    Logic giống ``upload_voice_record``: nếu teacher_id không tồn tại →
    fallback về teacher đầu tiên trong DB (MVP chưa có auth thật).
    """
    if teacher_id is not None:
        teacher = db.query(Teacher).filter(Teacher.teacher_id == teacher_id).first()
        if teacher is not None:
            return teacher.teacher_id

    fallback = db.query(Teacher).first()
    return fallback.teacher_id if fallback is not None else None


def resolve_child_id(db: Session, child_id: uuid.UUID | None) -> uuid.UUID | None:
    """Resolve child_id hợp lệ (fallback về child đầu tiên khi không tồn tại)."""
    if child_id is not None:
        child = db.query(Child).filter(Child.child_id == child_id).first()
        if child is not None:
            return child.child_id

    fallback = db.query(Child).first()
    return fallback.child_id if fallback is not None else None
