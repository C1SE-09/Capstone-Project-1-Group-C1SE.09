"""Celery task: đẩy lại các bản ghi bị kẹt do worker audio không chạy.

Task này chạy định kỳ (Celery Beat) để quét các ``VoiceRecord`` đang ở
``PENDING`` quá lâu và đẩy lại ``process_audio_task``.

Bối cảnh
---------
``process_audio_task.delay(...)`` chỉ đẩy task vào Redis **một lần**. Nếu
worker audio (RunPod) đang tắt đúng lúc giáo viên upload, task nằm im trong
Redis và bản ghi kẹt ở ``PENDING`` vĩnh viễn — cô ấy sẽ không bao giờ thấy
transcript. Task này là lưới an toàn: khi worker bật lại, các bản ghi kẹt
được đẩy lại tự động.
"""

import logging

from app.services.stt_dispatch_service import (
    MAX_DISPATCH_ATTEMPTS,
    STUCK_THRESHOLD_SECONDS,
    redispatch_stuck_records,
)
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="redispatch_stuck_voice_records")
def redispatch_stuck_voice_records() -> dict[str, int]:
    """Quét và đẩy lại các bản ghi bị kẹt ở trạng thái PENDING."""
    result = redispatch_stuck_records()
    logger.info("[RedispatchStuck] %s", result)
    return result


__all__ = [
    "redispatch_stuck_voice_records",
    "MAX_DISPATCH_ATTEMPTS",
    "STUCK_THRESHOLD_SECONDS",
]
