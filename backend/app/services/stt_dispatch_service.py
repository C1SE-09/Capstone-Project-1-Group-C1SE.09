"""
app/services/stt_dispatch_service.py
====================================
Đảm bảo bản ghi âm **luôn** được STT xử lý, kể cả khi:

1. Redis/Celery không sẵn sàng đúng lúc upload → task không vào được queue.
2. Worker audio (RunPod) đang tắt → task nằm im trong Redis vĩnh viễn.
3. App của giáo viên bị tắt giữa chừng → không liên quan (task đã ở server).

Vì sao cần module này?
---------------------
``process_audio_task.delay(...)`` là một lần **một lần duy nhất**: đẩy task
vào Redis rồi thôi. Nếu worker không chạy, task nằm đó mãi và
``VoiceRecord`` kẹt ở ``PENDING`` — giáo viên không bao giờ thấy transcript.

Module này bổ sung 2 cơ chế:

* :func:`dispatch_stt_task` — đẩy task, **bọc try/except**. Lỗi broker
  không được làm sập request upload (file đã lên MinIO, record đã tồn tại).
* :func:`redispatch_stuck_records` — quét các bản ghi kẹt lâu (> ngưỡng) và
  đẩy lại task. Chạy định kỳ bằng Celery Beat.

Ngưỡng & giới hạn
------------------
* Chỉ re-dispatch bản ghi đang ``PENDING`` (chưa ai xử lý) và đã quá ngưỡng.
* Tối đa ``MAX_DISPATCH_ATTEMPTS`` lần đẩy → không spam queue vô tận.
* Bản ghi ``PROCESSING`` được coi là đang chạy → không đụng vào.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.report import VoiceRecord, VoiceRecordStatus
from app.tasks.celery_app import celery_app

# ---------------------------------------------------------------------------
# Publish task STT
# ---------------------------------------------------------------------------
# Dùng `celery_app.send_task(<tên>)` thay vì import trực tiếp
# `app.tasks.process_audio`:
#
# 1. API container không cần load CTranslate2/PhoWhisper (2.9GB) → khởi động
#    nhanh, image nhẹ, không lỗi thiếu dependency.
# 2. Không import module nào của `app.tasks` → tránh circular import
#    (`app.tasks.__init__` ↔ `app.services.stt_dispatch_service`).
# 3. Worker `notifications` trên VPS (không GPU) vẫn đẩy được task sang
#    queue `audio` cho RunPod xử lý.
#
# `task_routes` trong celery_app.py ánh xạ tên task → queue, nên queue được
# chọn đúng dù gọi bằng tên.
STT_TASK_NAME = "process_audio_task"

# Timeout (giây) cho mọi thao tác mạng tới Redis.
#
# Mạng yếu ở trường là chuyện thường gặp → KHÔNG được để request upload
# treo vô hạn. Giá trị này đảm bảo request fail trong vài giây.
BROKER_TIMEOUT_SECONDS = 2


def publish_stt_task(voice_record_id: uuid.UUID | str) -> None:
    """Đẩy task STT lên queue ``audio`` (ném lỗi nếu broker không sẵn sàng).

    Vì sao không dùng ``celery_app.send_task(...)`` mặc định?
    ------------------------------------------------------
    Celery gọi ``ensure_connection(max_retries=None)`` → khi Redis chết,
    nó retry kết nối **vô hạn**, làm request upload của giáo viên treo
    (mất mạng ở trường là tình huống rất thường gặp).

    Ở đây ta tự mở connection với ``max_retries=0`` và timeout ngắn, nên
    lỗi được ném ra ngay lập tức. Lỗi này được ``dispatch_stt_task`` bắt
    và ghi log; bản ghi sẽ được đẩy lại bởi cơ chế re-dispatch.
    """
    with celery_app.connection_for_write(
        transport_options={
            "max_retries": 0,
            "socket_connect_timeout": BROKER_TIMEOUT_SECONDS,
            "socket_timeout": BROKER_TIMEOUT_SECONDS,
            "retry_on_timeout": False,
        }
    ) as connection:
        connection.ensure_connection(max_retries=0)
        celery_app.send_task(
            STT_TASK_NAME,
            args=[str(voice_record_id)],
            connection=connection,
            retry=False,
            retry_policy={"max_retries": 0},
        )

logger = logging.getLogger(__name__)


# ===========================================================================
# Constants
# ===========================================================================

# Bản ghi PENDING quá bao lâu thì coi là "kẹt" và cần đẩy lại.
#
# STT bình thường mất ~5-30s. Đặt ngưỡng 3 phút để:
# - không re-dispatch khi worker đang xử lý bình thường (chậm máy),
# - vẫn đủ nhanh để cô không phải chờ lâu khi RunPod bật lại.
STUCK_THRESHOLD_SECONDS = 180

# Tối đa số lần đẩy task cho 1 bản ghi.
#
# Task vào queue 1 lần là đủ nếu worker chạy. Ngưỡng này chỉ để tránh
# trường hợp worker cứ crash lúc xử lý → task bị reject → re-dispatch vô hạn.
MAX_DISPATCH_ATTEMPTS = 5


# ===========================================================================
# Helpers
# ===========================================================================


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _is_stuck(record: VoiceRecord, threshold_seconds: int) -> bool:
    """Record có đang kẹt (PENDING quá lâu, chưa được xử lý) không?"""
    if record.status != VoiceRecordStatus.PENDING:
        return False

    # Ưu tiên mốc đẩy task gần nhất; fallback về created_at.
    marker = record.last_stt_dispatch_at or record.created_at
    if marker is None:
        return False

    if marker.tzinfo is None:
        marker = marker.replace(tzinfo=timezone.utc)

    return (_now() - marker) > timedelta(seconds=threshold_seconds)


# ===========================================================================
# Public API
# ===========================================================================


def dispatch_stt_task(
    voice_record_id: uuid.UUID | str,
    db: Session | None = None,
    *,
    record_attempt: bool = True,
) -> bool:
    """
    Đẩy task STT cho 1 bản ghi, không để lỗi broker làm hỏng request.

    Args:
        voice_record_id: UUID của VoiceRecord
        db: SQLAlchemy session (nếu None → tự mở session riêng)
        record_attempt: Ghi nhận số lần đẩy vào DB (tắt khi gọi từ
            chính task để tránh vòng lặp)

    Returns:
        True nếu đẩy thành công, False nếu không đẩy được (lỗi hạ tầng).
    """
    own_session = db is None
    session = db or SessionLocal()
    try:
        try:
            publish_stt_task(voice_record_id)
        except Exception as exc:
            # Không được để lỗi broker (Redis down, mất mạng) làm sập
            # request upload — file audio đã lên MinIO và record đã có trong DB.
            logger.error(
                "[STTDispatch] Không đẩy được task STT cho %s: %s",
                voice_record_id,
                exc,
            )
            return False

        if record_attempt:
            record = (
                session.query(VoiceRecord)
                .filter(VoiceRecord.voice_record_id == uuid.UUID(str(voice_record_id)))
                .first()
            )
            if record is not None:
                record.stt_dispatch_attempts = (record.stt_dispatch_attempts or 0) + 1
                record.last_stt_dispatch_at = _now()
                session.commit()

        logger.info(
            "[STTDispatch] Đã đẩy task STT cho %s", voice_record_id
        )
        return True

    finally:
        if own_session:
            session.close()


def redispatch_stuck_records(
    db: Session | None = None,
    threshold_seconds: int = STUCK_THRESHOLD_SECONDS,
    max_attempts: int = MAX_DISPATCH_ATTEMPTS,
    teacher_id: uuid.UUID | None = None,
) -> dict[str, int]:
    """
    Quét các bản ghi bị kẹt và đẩy lại task STT.

    Dùng cho trường hợp worker audio (RunPod) đang tắt lúc giáo viên upload:
    task nằm im trong Redis, bản ghi kẹt ở ``PENDING``. Khi worker bật lại,
    task cũ vẫn được xử lý — nhưng nếu task đã bị mất (Redis restart, v.v.)
    thì cơ chế này sẽ đẩy lại.

    Args:
        db: SQLAlchemy session (nếu None → tự mở session riêng)
        threshold_seconds: Bản ghi PENDING quá bao lâu thì coi là kẹt
        max_attempts: Bỏ qua bản ghi đã đẩy quá số lần này
        teacher_id: Chỉ quét bản ghi của giáo viên này (None = tất cả)

    Returns:
        {"scanned": N, "redispatched": M, "skipped": K}
    """
    own_session = db is None
    session = db or SessionLocal()
    redispatched = 0
    skipped = 0

    try:
        query = session.query(VoiceRecord).filter(
            VoiceRecord.status == VoiceRecordStatus.PENDING
        )
        if teacher_id is not None:
            query = query.filter(VoiceRecord.teacher_id == teacher_id)

        candidates = query.all()

        for record in candidates:
            if (record.stt_dispatch_attempts or 0) >= max_attempts:
                skipped += 1
                logger.warning(
                    "[STTDispatch] Bỏ qua %s: đã đẩy %s lần (>= giới hạn %s)",
                    record.voice_record_id,
                    record.stt_dispatch_attempts,
                    max_attempts,
                )
                continue

            if not _is_stuck(record, threshold_seconds):
                continue

            if dispatch_stt_task(
                record.voice_record_id,
                db=session,
                record_attempt=True,
            ):
                redispatched += 1
            else:
                skipped += 1

        if redispatched:
            logger.info(
                "[STTDispatch] Đã đẩy lại %s bản ghi kẹt (quét %s)",
                redispatched,
                len(candidates),
            )

        return {
            "scanned": len(candidates),
            "redispatched": redispatched,
            "skipped": skipped,
        }

    finally:
        if own_session:
            session.close()
