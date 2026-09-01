from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str
    redis_url: str
    jwt_secret_key: str
    gemini_api_key: str

    # Cấu hình để Pydantic tự động đọc dữ liệu từ file .env
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


# Khởi tạo một biến settings duy nhất (Singleton) để dùng chung cho toàn bộ dự án
settings = Settings()