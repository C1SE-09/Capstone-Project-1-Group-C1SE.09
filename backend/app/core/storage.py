"""
app/core/storage.py
===================
MinIO client và helper functions để upload audio file.

MinIO là object storage tương thích S3, được deploy trong docker-compose.
Audio URL trả về là presigned URL public để Celery worker có thể đọc file.
"""

import io

from app.config import settings
from minio import Minio

# ---------------------------------------------------------------------------
# MinIO client (singleton)
# ---------------------------------------------------------------------------
minio_client = Minio(
    endpoint=settings.minio_endpoint,
    access_key=settings.minio_user,
    secret_key=settings.minio_password,
    secure=settings.minio_secure,
)


def _ensure_bucket_exists(bucket_name: str) -> None:
    """Tạo bucket nếu chưa tồn tại và đặt policy public-read."""
    if not minio_client.bucket_exists(bucket_name):
        minio_client.make_bucket(bucket_name)
        # Cho phép đọc public (không cần auth để GET file)
        policy = f"""{{
            "Version": "2012-10-17",
            "Statement": [{{
                "Effect": "Allow",
                "Principal": {{"AWS": ["*"]}},
                "Action": ["s3:GetObject"],
                "Resource": ["arn:aws:s3:::{bucket_name}/*"]
            }}]
        }}"""
        minio_client.set_bucket_policy(bucket_name, policy)


def upload_audio_to_minio(
    file_path: str,
    object_name: str,
    content_type: str = "audio/mpeg",
) -> str:
    """
    Upload file audio từ đường dẫn local lên MinIO bucket.

    Parameters
    ----------
    file_path   : Đường dẫn tạm thời của file (vd: /tmp/xyz.m4a)
    object_name : Tên object trong bucket (vd: teacher_uuid_uuid.m4a)
    content_type: MIME type của file audio

    Returns
    -------
    str : URL công khai để truy cập file, dạng http://minio:9000/audio/...
    """
    bucket = settings.minio_bucket
    _ensure_bucket_exists(bucket)

    minio_client.fput_object(
        bucket_name=bucket,
        object_name=object_name,
        file_path=file_path,
        content_type=content_type,
    )

    # Trả về URL dạng http://<endpoint>/<bucket>/<object>
    protocol = "https" if settings.minio_secure else "http"
    return f"{protocol}://{settings.minio_endpoint}/{bucket}/{object_name}"


def upload_audio_bytes_to_minio(
    data: bytes,
    object_name: str,
    content_type: str = "audio/mpeg",
) -> str:
    """
    Upload file audio từ bytes lên MinIO bucket (không cần temp file).

    Returns
    -------
    str : URL công khai để truy cập file
    """
    bucket = settings.minio_bucket
    _ensure_bucket_exists(bucket)

    minio_client.put_object(
        bucket_name=bucket,
        object_name=object_name,
        data=io.BytesIO(data),
        length=len(data),
        content_type=content_type,
    )

    protocol = "https" if settings.minio_secure else "http"
    return f"{protocol}://{settings.minio_endpoint}/{bucket}/{object_name}"
