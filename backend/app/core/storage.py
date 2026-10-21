"""
app/core/storage.py
===================
MinIO client và helper functions để upload audio file.

MinIO là object storage tương thích S3, được deploy trong docker-compose.
Audio URL trả về là presigned URL public để Celery worker có thể đọc file.
"""

import io
import logging
import shutil
from urllib.parse import unquote, urlsplit

from minio import Minio

from app.config import settings

logger = logging.getLogger(__name__)

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
    try:
        minio_client.set_bucket_policy(bucket_name, policy)
    except Exception as exc:
        # Bucket private vẫn upload được; chỉ khiến worker không tải được bằng
        # HTTP ẩn danh. Worker có fallback sang MinIO SDK nên vẫn chạy được.
        logger.warning(
            "[MinIO] Không đặt được policy public-read cho bucket %s: %s",
            bucket_name,
            exc,
        )


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


# ---------------------------------------------------------------------------
# Download helper (dùng bởi Celery worker)
# ---------------------------------------------------------------------------


def object_name_from_url(url: str) -> str | None:
    """
    Trích object key từ URL MinIO dạng ``<scheme>://<endpoint>/<bucket>/<object>``.

    Trả về None nếu URL không có dạng trên.
    """
    try:
        path = unquote(urlsplit(url).path or "").lstrip("/")
    except ValueError:
        return None
    if not path or "/" not in path:
        return None

    bucket_prefix = f"{settings.minio_bucket}/"
    if path.startswith(bucket_prefix):
        return path[len(bucket_prefix) :]
    # URL trỏ sang bucket khác → bỏ segment đầu tiên (tên bucket).
    return path.split("/", 1)[1]


def fetch_audio_from_minio(url: str, local_path: str) -> None:
    """
    Tải audio từ MinIO bằng SDK (có credentials) và ghi ra ``local_path``.

    Worker dùng cách này làm fallback khi HTTP GET trực tiếp thất bại, vì
    ``audio_url`` được sinh ở máy API nên hostname trong đó có thể không phân
    giải được từ container worker (ví dụ ``localhost`` khi API chạy ngoài
    Docker nhưng worker chạy trong Docker).
    """
    object_name = object_name_from_url(url)
    if not object_name:
        raise ValueError(f"Không phân tích được object key từ URL: {url}")

    response = minio_client.get_object(settings.minio_bucket, object_name)
    try:
        with response as stream, open(local_path, "wb") as out_file:
            shutil.copyfileobj(stream, out_file)
    finally:
        response.close()
        response.release_conn()
