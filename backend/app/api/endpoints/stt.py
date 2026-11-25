import logging
import os
import tempfile
from typing import Annotated

from app.core.security import require_roles
from app.models.user import User
from app.services.stt_service import stt_service
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

logger = logging.getLogger(__name__)
_MAX_STT_FILE_BYTES = 25 * 1024 * 1024  # 25 MB
_CHUNK_SIZE = 1024 * 1024  # 1 MB

# Khởi tạo router cho nhóm endpoint STT (Speech-to-Text)
# Router này sẽ được đăng ký vào app chính với prefix (ví dụ: /api/stt)
router = APIRouter()

# Các định dạng audio được chấp nhận. Giữ nguyên phần mở rộng gốc để bộ giải mã
# (faster-whisper/PyAV) nhận đúng container, tránh lỗi với .m4a/.mp3/.webm.
_ALLOWED_SUFFIXES = {
    ".wav",
    ".mp3",
    ".m4a",
    ".mp4",
    ".aac",
    ".ogg",
    ".oga",
    ".opus",
    ".flac",
    ".webm",
    ".amr",
    ".3gp",
}


def _resolve_suffix(filename: str | None) -> str:
    """Suy ra phần mở rộng hợp lệ từ tên file gốc (mặc định .wav)."""
    suffix = os.path.splitext(filename or "")[1].lower()
    if suffix in _ALLOWED_SUFFIXES:
        return suffix
    return ".wav"


@router.post("/transcribe")
async def transcribe(
    audio: Annotated[UploadFile, File()],
    _current_user: User = Depends(require_roles("teacher", "admin")),
):
    """Nhận file âm thanh từ client, trả về văn bản đã nhận dạng (STT)."""

    # Lưu file upload vào file tạm, GIỮ ĐÚNG phần mở rộng gốc để giải mã đúng
    # định dạng (delete=False để STTService có thể mở sau khi đóng).
    tmp_path = None
    try:
        suffix = _resolve_suffix(audio.filename)
        total_bytes = 0
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp_path = tmp.name
            while True:
                chunk = await audio.read(_CHUNK_SIZE)
                if not chunk:
                    break
                total_bytes += len(chunk)
                if total_bytes > _MAX_STT_FILE_BYTES:
                    raise ValueError("File âm thanh vượt quá giới hạn cho phép (25 MB).")
                tmp.write(chunk)

        # Gọi STTService để chuyển đổi file âm thanh tạm thành văn bản
        text = stt_service.transcribe(tmp_path)

        # Trả về kết quả gồm tên file gốc và văn bản nhận dạng được
        return {"filename": audio.filename, "text": text}

    except FileNotFoundError as e:
        logger.warning("[STT] File audio không tìm thấy: %s", e)
        raise HTTPException(
            status_code=400,
            detail="Không tìm thấy file âm thanh để xử lý.",
        ) from e
    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e) if "25 MB" in str(e) else "File âm thanh không hợp lệ.",
        ) from e
    except Exception as e:
        logger.exception("[STT] Lỗi xử lý STT: %s", e)
        raise HTTPException(
            status_code=500,
            detail="Không thể xử lý chuyển đổi giọng nói lúc này. Vui lòng thử lại sau.",
        ) from e
    finally:
        # Luôn xóa file tạm sau khi xử lý xong, dù thành công hay thất bại
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
