import os
import tempfile
from typing import Annotated

from app.services.stt_service import stt_service
from fastapi import APIRouter, File, HTTPException, UploadFile

# Khởi tạo router cho nhóm endpoint STT (Speech-to-Text)
# Router này sẽ được đăng ký vào app chính với prefix (ví dụ: /api/stt)
router = APIRouter()


@router.post("/transcribe")
async def transcribe(audio: Annotated[UploadFile, File(...)]):
    """
    Endpoint nhận file âm thanh từ client và trả về văn bản đã được nhận dạng.

    - **audio**: File âm thanh upload lên (định dạng .wav, .mp3, v.v.)

    Returns:
        JSON gồm:
            - `filename`: Tên file gốc do client gửi lên.
            - `text`: Chuỗi văn bản được nhận dạng từ file âm thanh.

    Raises:
        HTTPException (400): Nếu quá trình nhận dạng thất bại (file lỗi, định dạng không hỗ trợ, v.v.)
    """
    # Lưu nội dung file âm thanh vào một file tạm thời trên server
    # delete=False: giữ file lại sau khi đóng để STTService có thể đọc
    # suffix=".wav": đảm bảo file tạm có đuôi .wav để model nhận diện đúng định dạng
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp.write(await audio.read())  # Đọc toàn bộ nội dung file upload và ghi vào file tạm
        tmp_path = tmp.name           # Lưu đường dẫn file tạm để dùng sau

    try:
        # Gọi STTService để chuyển đổi file âm thanh tạm thành văn bản
        text = stt_service.transcribe(tmp_path)

        # Trả về kết quả gồm tên file gốc và văn bản nhận dạng được
        return {"filename": audio.filename, "text": text}

    except (FileNotFoundError, RuntimeError, ValueError) as e:
        # Nếu xảy ra lỗi trong quá trình nhận dạng, trả về HTTP 400 với thông báo lỗi
        raise HTTPException(status_code=400, detail=str(e)) from e

    finally:
        # Luôn xóa file tạm sau khi xử lý xong (dù thành công hay thất bại)
        # để tránh tích lũy file rác trên server
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
