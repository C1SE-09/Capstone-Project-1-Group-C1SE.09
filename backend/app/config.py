from pydantic_settings import BaseSettings, SettingsConfigDict

from datetime import date, datetime, timedelta, timezone

vn_tz = timezone(timedelta(hours=7))

def get_today() -> date:
    """Trả về ngày hôm nay theo giờ Việt Nam (UTC+7)"""
    return datetime.now(vn_tz).date()
class Settings(BaseSettings):
    # Database & cache
    database_url: str = (
        "postgresql+psycopg://kinderlog:change-me@localhost:5432/kinderlog"
    )
    redis_url: str = "redis://localhost:6379/0"

    # Security
    jwt_secret_key: str = "change-me"

    # AI (optional until sprint 2)
    gemini_api_key: str = ""

    # Firebase Cloud Messaging (push notification) — đường dẫn service account JSON
    firebase_credentials_path: str = ""

    # MinIO object storage
    minio_endpoint: str = "localhost:9000"
    minio_user: str = "minioadmin"
    minio_password: str = "minioadmin123"
    minio_bucket: str = "audio"
    minio_secure: bool = False

    # SMTP Email
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from: str = ""

    # Bug report notifications (B-04)
    # Comma-separated list of admin emails to notify when new bug report created.
    # Nếu rỗng → sẽ tìm tất cả User.role=ADMIN và gửi tới email của họ (nếu có).
    bug_report_notify_email: str = ""

    # Cấu hình để Pydantic tự động đọc dữ liệu từ file .env
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )


# Khởi tạo một biến settings duy nhất (Singleton) để dùng chung cho toàn bộ dự án
settings = Settings()
