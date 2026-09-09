from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Database & cache
    database_url: str
    redis_url: str

    # Security
    jwt_secret_key: str = "change-me"

    # AI (optional until sprint 2)
    gemini_api_key: str = ""

    # MinIO object storage
    minio_endpoint: str = "minio:9000"
    minio_user: str = "minioadmin"
    minio_password: str = "minioadmin123"
    minio_bucket: str = "audio"
    minio_secure: bool = False

    # Cấu hình để Pydantic tự động đọc dữ liệu từ file .env
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


# Khởi tạo một biến settings duy nhất (Singleton) để dùng chung cho toàn bộ dự án
settings = Settings()