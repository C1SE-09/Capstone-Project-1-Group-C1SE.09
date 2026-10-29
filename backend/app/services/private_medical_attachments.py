"""Ảnh y tế riêng tư: chỉ nhận bytes, không tải URL do client cung cấp."""

import io
import logging
import uuid

from fastapi import HTTPException
from minio.error import S3Error

from app.config import settings
from app.core import storage

logger = logging.getLogger(__name__)

MAX_IMAGE_BYTES = 5 * 1024 * 1024
IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _unavailable() -> HTTPException:
    # Không log exception SDK: có thể chứa credentials hoặc thông tin ảnh riêng tư.
    logger.warning("Kho ảnh y tế riêng tư tạm thời không khả dụng")
    return HTTPException(status_code=503, detail="Kho ảnh tạm thời không khả dụng, vui lòng thử lại")


def validate_image(data: bytes, content_type: str | None) -> None:
    signatures_match = (
        (content_type == "image/jpeg" and data.startswith(b"\xff\xd8\xff"))
        or (content_type == "image/png" and data.startswith(b"\x89PNG\r\n\x1a\n"))
        or (content_type == "image/webp" and len(data) >= 12
            and data[:4] == b"RIFF" and data[8:12] == b"WEBP")
    )
    if not data or len(data) > MAX_IMAGE_BYTES or not signatures_match:
        raise HTTPException(status_code=422, detail="Ảnh phải là JPEG/PNG/WebP hợp lệ và không quá 5 MiB")


def save_private_image(*, child_id: uuid.UUID, user_id: uuid.UUID, data: bytes,
                       content_type: str | None, bucket_suffix: str, url_prefix: str) -> str:
    validate_image(data, content_type)
    attachment_id = uuid.uuid4()
    key = f"{child_id}/{attachment_id}"
    bucket = f"{settings.minio_bucket}{bucket_suffix}"
    try:
        client = storage.minio_client
        if not client.bucket_exists(bucket):
            try:
                client.make_bucket(bucket)
            except S3Error as exc:
                if exc.code != "BucketAlreadyOwnedByYou":
                    raise
        # Bucket mới mặc định private; xóa policy cũ nếu từng bị cấu hình public.
        client.delete_bucket_policy(bucket)
        client.put_object(
            bucket_name=bucket, object_name=key, data=io.BytesIO(data), length=len(data),
            content_type=content_type,
            metadata={"child-id": str(child_id), "uploader-id": str(user_id)},
        )
    except Exception:
        raise _unavailable() from None
    return f"{url_prefix}{key}"


def _stat_image(child_id: uuid.UUID, attachment_id: uuid.UUID, bucket_suffix: str):
    try:
        return storage.minio_client.stat_object(
            f"{settings.minio_bucket}{bucket_suffix}", f"{child_id}/{attachment_id}",
        )
    except S3Error as exc:
        if exc.code in {"NoSuchKey", "NoSuchObject"}:
            raise HTTPException(status_code=404, detail="Không tìm thấy ảnh đính kèm") from None
        raise _unavailable() from None
    except Exception:
        raise _unavailable() from None


def validate_private_image_reference(*, path: str, child_id: uuid.UUID, user_id: uuid.UUID,
                                     bucket_suffix: str, url_prefix: str) -> None:
    prefix = f"{url_prefix}{child_id}/"
    try:
        attachment_id = uuid.UUID(path.removeprefix(prefix))
    except ValueError:
        raise HTTPException(status_code=422, detail="Đường dẫn ảnh đính kèm không hợp lệ") from None
    if path != f"{prefix}{attachment_id}":
        raise HTTPException(status_code=422, detail="Ảnh đính kèm không thuộc bé này")
    info = _stat_image(child_id, attachment_id, bucket_suffix)
    metadata = {key.lower(): value for key, value in info.metadata.items()}
    if (metadata.get("x-amz-meta-child-id") != str(child_id)
            or metadata.get("x-amz-meta-uploader-id") != str(user_id)):
        raise HTTPException(status_code=403, detail="Ảnh đính kèm không thuộc bé và người gửi")
    if info.content_type not in IMAGE_TYPES or not 0 < info.size <= MAX_IMAGE_BYTES:
        raise HTTPException(status_code=422, detail="Ảnh đính kèm không hợp lệ")


def read_private_image(*, child_id: uuid.UUID, attachment_id: uuid.UUID, bucket_suffix: str) -> tuple[bytes, str]:
    info = _stat_image(child_id, attachment_id, bucket_suffix)
    metadata = {key.lower(): value for key, value in info.metadata.items()}
    if metadata.get("x-amz-meta-child-id") != str(child_id):
        raise HTTPException(status_code=404, detail="Không tìm thấy ảnh đính kèm")
    if info.content_type not in IMAGE_TYPES or not 0 < info.size <= MAX_IMAGE_BYTES:
        raise _unavailable()
    try:
        response = storage.minio_client.get_object(
            f"{settings.minio_bucket}{bucket_suffix}", f"{child_id}/{attachment_id}",
        )
        try:
            data = response.read(MAX_IMAGE_BYTES + 1)
        finally:
            response.close()
            response.release_conn()
        validate_image(data, info.content_type)
        if len(data) != info.size:
            raise ValueError("Ảnh lưu không đầy đủ")
    except Exception:
        raise _unavailable() from None
    return data, info.content_type
