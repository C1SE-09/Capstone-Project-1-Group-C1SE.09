import logging
from typing import Annotated

from app.core.security import require_roles
from app.models.user import User
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

logger = logging.getLogger(__name__)

# Khởi tạo router cho nhóm endpoint STT (Speech-to-Text)
# Router này sẽ được đăng ký vào app chính với prefix (ví dụ: /api/stt)
router = APIRouter()


@router.post("/transcribe")
async def transcribe(
    audio: Annotated[UploadFile, File()],
    _current_user: User = Depends(require_roles("teacher", "admin")),
):
    """Vô hiệu hóa STT đồng bộ trên luồng HTTP để tránh chặn event loop và OOM trên API server.

    Toàn bộ tác vụ chuyển đổi giọng nói PhoWhisper phải đi qua luồng bất đồng bộ
    `POST /api/teacher/voice/upload` để Celery GPU worker xử lý.
    """
    logger.warning(
        "[STT] Từ chối yêu cầu STT đồng bộ cho file=%s; vui lòng dùng luồng Celery bất đồng bộ.",
        audio.filename,
    )
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail=(
            "Chức năng chuyển đổi giọng nói đồng bộ đã tạm ngưng để đảm bảo ổn định hệ thống. "
            "Vui lòng sử dụng luồng tải lên bất đồng bộ (/api/teacher/voice/upload)."
        ),
    )
