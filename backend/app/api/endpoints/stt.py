import os
import tempfile

from app.services.stt_service import stt_service
from fastapi import APIRouter, HTTPException, UploadFile

# Khởi tạo router cho nhóm endpoint STT (Speech-to-Text)
# Router này sẽ được đăng ký vào app chính với prefix (ví dụ: /api/stt)
router = APIRouter()


@router.post("/transcribe")
async def transcribe(audio: UploadFile):
    """Nhận file âm thanh từ client, trả về văn bản đã nhận dạng (STT)."""
    if not isinstance(audio, UploadFile):
        raise HTTPException(status_code=400, detail="File âm thanh là bắt buộc")

    # Lưu file upload vào file tạm (delete=False để STTService có thể mở sau khi đóng)
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            tmp.write(await audio.read())
            tmp_path = tmp.name

        # Gọi STTService để chuyển đổi file âm thanh tạm thành văn bản
        text = stt_service.transcribe(tmp_path)

        # Trả về kết quả gồm tên file gốc và văn bản nhận dạng được
        return {"filename": audio.filename, "text": text}

    except FileNotFoundError as e:
        raise HTTPException(
            status_code=400,
            detail=f"File audio không tìm thấy: {e!s}",
        ) from e
    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=f"File audio không hợp lệ: {e!s}",
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi xử lý STT: {e!s}",
        ) from e
    finally:
        # Luôn xóa file tạm sau khi xử lý xong, dù thành công hay thất bại
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
