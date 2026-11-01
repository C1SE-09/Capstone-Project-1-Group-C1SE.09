"""
app/core/public_url.py
======================
Xây dựng URL công khai cho object trên MinIO.

Tách khỏi ``app.core.storage`` để schema/response có thể chuẩn hoá URL mà
không cần import MinIO client.
"""

from urllib.parse import urlsplit

from app.config import settings

_INTERNAL_MINIO_HOSTS = {"minio", "localhost", "127.0.0.1"}


def build_public_url(bucket_name: str, object_name: str) -> str:
    """URL công khai của object, ưu tiên ``MINIO_PUBLIC_URL`` khi đã cấu hình."""
    base = settings.minio_public_url.rstrip("/")
    if base:
        return f"{base}/{bucket_name}/{object_name}"

    endpoint = settings.minio_endpoint
    # Hostname "minio" chỉ phân giải được bên trong docker-compose.
    if endpoint.startswith("minio:"):
        endpoint = "localhost:" + endpoint.split(":", 1)[1]
    elif endpoint == "minio":
        endpoint = "localhost:9000"

    protocol = "https" if settings.minio_secure else "http"
    return f"{protocol}://{endpoint}/{bucket_name}/{object_name}"


def normalize_public_url(url: str) -> str:
    """Đổi URL cũ trỏ vào host nội bộ (minio/localhost:9000) sang ``MINIO_PUBLIC_URL``.

    Dữ liệu đã lưu trong DB từ trước khi cấu hình ``MINIO_PUBLIC_URL`` vẫn là
    ``http://minio:9000/...`` hoặc ``http://localhost:9000/...``. Chuẩn hoá lúc
    đọc để không phải chạy migration backfill.
    """
    base = settings.minio_public_url.rstrip("/")
    if not base or not url:
        return url
    try:
        parts = urlsplit(url)
        is_internal = (
            parts.hostname in _INTERNAL_MINIO_HOSTS and parts.port in (None, 9000)
        )
    except ValueError:
        return url
    if not is_internal:
        return url
    query = f"?{parts.query}" if parts.query else ""
    return f"{base}{parts.path}{query}"
