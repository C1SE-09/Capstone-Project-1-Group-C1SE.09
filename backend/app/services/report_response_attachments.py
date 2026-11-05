"""
app/services/report_response_attachments.py
==========================================
Ảnh đính kèm trong phản hồi báo cáo — dùng lại kho ảnh private có sẵn.

Vì sao không dùng bucket công khai?
-----------------------------------
Ảnh phản hồi có thể chứa thông tin sức khoẻ của trẻ (ví dụ: "bé sốt, đã
đưa đi khám, đây là ảnh giấy khám"). Đường dẫn lưu trong DB chỉ là đường dẫn
NỘI BỘ dạng ``/api/report-responses/attachments/{child_id}/{attachment_id}``;
bytes thật nằm trong bucket MinIO private và chỉ được đọc qua endpoint có
kiểm tra quyền (giáo viên của lớp / phụ huynh của bé / admin).

Pattern tái sử dụng từ ``app.services.private_medical_attachments`` —
giữ nguyên cơ chế: nhận bytes trực tiếp (không nhận URL do client cung cấp),
kiểm tra magic bytes, bucket riêng, metadata child-id/uploader-id để chặn
truy cập chéo bé.
"""

from __future__ import annotations

import uuid

from app.services.private_medical_attachments import (
    IMAGE_TYPES as IMAGE_TYPES,
    MAX_IMAGE_BYTES as MAX_IMAGE_BYTES,
    read_private_image as _read_private_image,
    save_private_image as _save_private_image,
    validate_image as validate_image,
    validate_private_image_reference as _validate_reference,
)

ATTACHMENT_PREFIX = "/api/report-responses/attachments/"
_BUCKET_SUFFIX = "-report-responses"


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


def extract_attachment_id(path: str) -> uuid.UUID:
    """Rút ra attachment_id từ đường dẫn nội bộ đã lưu trong DB."""
    try:
        return uuid.UUID(path.rsplit("/", 1)[1])
    except (ValueError, IndexError):
        raise ValueError("Đường dẫn ảnh đính kèm không hợp lệ") from None
