"""
app/tasks/audio.py
==================
Celery task xử lý audio sau khi upload.

Flow:
    1. Đổi VoiceRecord.status = PROCESSING
    2. Gọi Gemini Speech-to-Text để transcribe
    3. Tạo DailyReport từ nội dung transcription
    4. Đổi VoiceRecord.status = COMPLETED (hoặc FAILED nếu lỗi)

MVP: Hiện tại là stub — chỉ log thông tin, chưa gọi Gemini.
     Sẽ implement đầy đủ trong sprint tiếp theo.
"""

import logging

from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="process_audio", bind=True, max_retries=3)
def process_audio(self, voice_record_id: str) -> dict:
    """
    Transcribe audio và tạo DailyReport từ VoiceRecord.

    Parameters
    ----------
    voice_record_id : str
        UUID string của VoiceRecord cần xử lý.

    Returns
    -------
    dict : {"voice_record_id": str, "status": str}

    TODO (sprint 2)
    ---------------
    - Tải audio URL từ DB
    - Gọi Gemini STT API để transcribe
    - Parse kết quả thành các ActivityEntry
    - Tạo DailyReport với status=DRAFT
    - Cập nhật VoiceRecord.status = COMPLETED
    """
    logger.info("[process_audio] Received task for voice_record_id=%s", voice_record_id)

    # TODO: Implement Gemini transcription pipeline
    # Placeholder: chỉ log, chưa làm gì thêm

    logger.info(
        "[process_audio] Stub complete for voice_record_id=%s — "
        "Gemini pipeline not yet implemented",
        voice_record_id,
    )

    return {"voice_record_id": voice_record_id, "status": "pending"}
