from fastapi import APIRouter, File, UploadFile, HTTPException
import tempfile
import os

from app.services.stt_service import stt_service

router = APIRouter()


@router.post("/transcribe")
async def transcribe(audio: UploadFile = File(...)):
    """Nhận file âm thanh từ client, trả về văn bản đã nhận dạng (STT)."""
    # Lưu file upload vào file tạm (delete=False để STTService có thể mở sau khi đóng)
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp.write(await audio.read())
        tmp_path = tmp.name

    try:
        text = stt_service.transcribe(tmp_path)
        return {"filename": audio.filename, "text": text}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        # Luôn xóa file tạm sau khi xử lý xong, dù thành công hay thất bại
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
