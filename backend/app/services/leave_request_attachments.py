"""Giữ hợp đồng ảnh xin phép cũ, dùng chung kho ảnh y tế private."""

import uuid

from app.services.private_medical_attachments import (
    IMAGE_TYPES as IMAGE_TYPES,
    MAX_IMAGE_BYTES as MAX_IMAGE_BYTES,
    read_private_image,
    save_private_image,
    validate_image as validate_image,
    validate_private_image_reference,
)

ATTACHMENT_PREFIX = "/api/leave-requests/attachments/"
_BUCKET_SUFFIX = "-leave-requests"


def save_attachment(child_id: uuid.UUID, user_id: uuid.UUID, data: bytes, content_type: str | None) -> str:
    return save_private_image(child_id=child_id, user_id=user_id, data=data, content_type=content_type,
                              bucket_suffix=_BUCKET_SUFFIX, url_prefix=ATTACHMENT_PREFIX)


def validate_attachment_reference(path: str, child_id: uuid.UUID, user_id: uuid.UUID) -> None:
    validate_private_image_reference(path=path, child_id=child_id, user_id=user_id,
                                     bucket_suffix=_BUCKET_SUFFIX, url_prefix=ATTACHMENT_PREFIX)


def read_attachment(child_id: uuid.UUID, attachment_id: uuid.UUID) -> tuple[bytes, str]:
    return read_private_image(child_id=child_id, attachment_id=attachment_id, bucket_suffix=_BUCKET_SUFFIX)


def copy_attachment_for_child(path: str, source_child_id: uuid.UUID, child_id: uuid.UUID, user_id: uuid.UUID) -> str:
    """Tách ảnh chung theo bé, không mở rộng quyền đọc sang ảnh/hồ sơ bé khác."""
    validate_attachment_reference(path, source_child_id, user_id)
    # shortcut: ảnh tối đa 5 MiB; dùng server-side copy khi batch lớn.
    data, content_type = read_attachment(source_child_id, uuid.UUID(path.rsplit("/", 1)[1]))
    return save_attachment(child_id, user_id, data, content_type)
