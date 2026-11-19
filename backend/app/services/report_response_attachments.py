"""
app/services/report_response_attachments.py
==========================================
Tệp đính kèm (ảnh và âm thanh) trong phản hồi báo cáo — lưu trữ kho private MinIO.

Vì sao không dùng bucket công khai?
-----------------------------------
Ảnh hoặc bản ghi âm phản hồi có thể chứa thông tin nhạy cảm của trẻ.
Đường dẫn lưu trong DB chỉ là đường dẫn NỘI BỘ dạng:
- ``/api/report-responses/attachments/{child_id}/{attachment_id}`` (Ảnh)
- ``/api/report-responses/audio/{child_id}/{attachment_id}`` (Tin nhắn thoại)
Bytes thật nằm trong bucket MinIO private và chỉ được đọc qua endpoint có
kiểm tra quyền (giáo viên của lớp / phụ huynh của bé / admin).
"""

from __future__ import annotations

import io
import uuid

from fastapi import HTTPException
from minio.error import S3Error

from app.config import settings
from app.core import storage
from app.services.private_medical_attachments import (
    IMAGE_TYPES as IMAGE_TYPES,
    MAX_IMAGE_BYTES as MAX_IMAGE_BYTES,
    _stat_image,
    _unavailable,
    read_private_image as _read_private_image,
    save_private_image as _save_private_image,
    validate_image as validate_image,
    validate_private_image_reference as _validate_reference,
)

ATTACHMENT_PREFIX = "/api/report-responses/attachments/"
AUDIO_PREFIX = "/api/report-responses/audio/"
_BUCKET_SUFFIX = "-report-responses"

MAX_AUDIO_BYTES = 15 * 1024 * 1024  # 15 MiB
AUDIO_TYPES = {
    "audio/m4a",
    "audio/mp4",
    "audio/aac",
    "audio/x-m4a",
    "audio/mpeg",
    "audio/mp3",
    "audio/wav",
    "audio/wave",
    "audio/x-wav",
    "audio/ogg",
    "audio/webm",
}


def validate_audio(data: bytes, content_type: str | None) -> str:
    """Kiểm tra bytes âm thanh và trả về content_type chuẩn hoá."""
    if not data or len(data) > MAX_AUDIO_BYTES:
        raise HTTPException(
            status_code=422,
            detail="File ghi âm không được rỗng và không quá 15 MiB",
        )
    ct = (content_type or "").lower().split(";")[0].strip()
    if ct not in AUDIO_TYPES and ct != "application/octet-stream":
        if data.startswith(b"RIFF") and b"WAVE" in data[:16]:
            return "audio/wav"
        if data.startswith(b"\xff\xfb") or data.startswith(b"\xff\xf3") or data.startswith(b"ID3"):
            return "audio/mpeg"
        if b"ftyp" in data[:12]:
            return "audio/m4a"
        if data.startswith(b"OggS"):
            return "audio/ogg"
        raise HTTPException(
            status_code=422,
            detail="Định dạng âm thanh không được hỗ trợ (chỉ nhận m4a, aac, mp3, wav, ogg)",
        )
    if ct == "application/octet-stream":
        return "audio/m4a"
    return ct


def save_attachment(
    *,
    child_id: uuid.UUID,
    user_id: uuid.UUID,
    data: bytes,
    content_type: str | None,
) -> str:
    """Lưu ảnh vào kho private và trả về đường dẫn nội bộ."""
    return _save_private_image(
        child_id=child_id,
        user_id=user_id,
        data=data,
        content_type=content_type,
        bucket_suffix=_BUCKET_SUFFIX,
        url_prefix=ATTACHMENT_PREFIX,
    )


def save_audio_attachment(
    *,
    child_id: uuid.UUID,
    user_id: uuid.UUID,
    data: bytes,
    content_type: str | None,
) -> str:
    """Lưu file âm thanh ghi âm vào kho private và trả về đường dẫn nội bộ."""
    resolved_ct = validate_audio(data, content_type)
    attachment_id = uuid.uuid4()
    key = f"{child_id}/{attachment_id}"
    bucket = f"{settings.minio_bucket}{_BUCKET_SUFFIX}"
    try:
        client = storage.minio_client
        if not client.bucket_exists(bucket):
            try:
                client.make_bucket(bucket)
            except S3Error as exc:
                if exc.code != "BucketAlreadyOwnedByYou":
                    raise
        client.delete_bucket_policy(bucket)
        client.put_object(
            bucket_name=bucket,
            object_name=key,
            data=io.BytesIO(data),
            length=len(data),
            content_type=resolved_ct,
            metadata={"child-id": str(child_id), "uploader-id": str(user_id)},
        )
    except Exception:
        raise _unavailable() from None
    return f"{AUDIO_PREFIX}{key}"


def validate_attachment_reference(
    *, path: str, child_id: uuid.UUID, user_id: uuid.UUID
) -> None:
    """Kiểm tra đường dẫn ảnh thuộc đúng bé + đúng người gửi."""
    _validate_reference(
        path=path,
        child_id=child_id,
        user_id=user_id,
        bucket_suffix=_BUCKET_SUFFIX,
        url_prefix=ATTACHMENT_PREFIX,
    )


def read_attachment(
    *, child_id: uuid.UUID, attachment_id: uuid.UUID
) -> tuple[bytes, str]:
    """Đọc bytes ảnh + content type từ kho private."""
    return _read_private_image(
        child_id=child_id,
        attachment_id=attachment_id,
        bucket_suffix=_BUCKET_SUFFIX,
    )


def read_audio_attachment(
    *, child_id: uuid.UUID, attachment_id: uuid.UUID
) -> tuple[bytes, str]:
    """Đọc bytes âm thanh + content type từ kho private."""
    info = _stat_image(child_id, attachment_id, _BUCKET_SUFFIX)
    metadata = {key.lower(): value for key, value in info.metadata.items()}
    if metadata.get("x-amz-meta-child-id") != str(child_id):
        raise HTTPException(status_code=404, detail="Không tìm thấy file âm thanh")
    try:
        response = storage.minio_client.get_object(
            f"{settings.minio_bucket}{_BUCKET_SUFFIX}", f"{child_id}/{attachment_id}"
        )
        try:
            data = response.read(MAX_AUDIO_BYTES + 1)
        finally:
            response.close()
            response.release_conn()
        if len(data) != info.size:
            raise ValueError("File âm thanh lưu không đầy đủ")
    except Exception:
        raise _unavailable() from None
    return data, info.content_type


def extract_attachment_id(path: str) -> uuid.UUID:
    """Rút ra attachment_id từ đường dẫn nội bộ đã lưu trong DB."""
    try:
        return uuid.UUID(path.rsplit("/", 1)[1])
    except (ValueError, IndexError):
        raise ValueError("Đường dẫn đính kèm không hợp lệ") from None
