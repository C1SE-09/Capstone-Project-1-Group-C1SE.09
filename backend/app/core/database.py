"""
app/core/database.py
====================
SQLAlchemy engine setup và FastAPI dependency get_db().

Dùng psycopg3 sync driver (postgresql+psycopg) khớp với DATABASE_URL trong .env.
FastAPI sẽ chạy các endpoint sync trong thread-pool tự động.
"""

from collections.abc import Generator

from app.config import settings
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

# ---------------------------------------------------------------------------
# Engine (tái sử dụng kết nối qua connection pool)
# ---------------------------------------------------------------------------
engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,  # kiểm tra kết nối trước khi dùng (tránh stale connections)
    pool_size=10,
    max_overflow=20,
    echo=False,  # Đổi thành True để debug SQL query
)

# ---------------------------------------------------------------------------
# Session factory
# ---------------------------------------------------------------------------
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)


# ---------------------------------------------------------------------------
# FastAPI Dependency
# ---------------------------------------------------------------------------
def get_db() -> Generator[Session, None, None]:
    """
    Yield một database session rồi tự động đóng sau khi request kết thúc.

    Cách dùng trong endpoint:
        def my_endpoint(db: Session = Depends(get_db)):
            ...
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
