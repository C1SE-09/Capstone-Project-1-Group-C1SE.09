from __future__ import annotations

import re

from celery import Celery

from app.config import settings


def _backend_url(broker: str) -> str:
    """Tạo Redis URL cho result backend từ broker URL.

    Đổi DB index cuối thành /1 để tách broker và result backend,
    tránh Celery result key xung đột với app cache key.
    Ví dụ: "redis://redis:6379/0" → "redis://redis:6379/1"
    """
    return re.sub(r"/\d+$", "/1", broker)


# Celery app dùng chung toàn bộ project
# Broker & Backend đều trỏ vào Redis lấy từ settings.redis_url (đọc từ .env)
celery_app = Celery(
    "kinderlog",
    broker=settings.redis_url,
    backend=_backend_url(settings.redis_url),
    include=[
        "app.tasks.audio",          # ping smoke-test task
        "app.tasks.process_audio",  # PhoWhisper STT pipeline task
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    worker_max_tasks_per_child=10,          # Giải phóng bộ nhớ GPU sau mỗi 10 task
    broker_connection_retry_on_startup=True,
    task_routes={
        "process_audio_task": {"queue": "audio"},  # Route STT task vào queue riêng
    },
)


@celery_app.task(name="ping")
def ping() -> str:
    """Health-check: xác nhận worker kết nối được Redis."""
    return "pong"
