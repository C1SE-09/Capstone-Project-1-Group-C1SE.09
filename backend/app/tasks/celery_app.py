import os

from celery import Celery

celery_app = Celery(
    "kinderlog",
    broker=os.getenv("CELERY_BROKER_URL", "redis://redis:6379/0"),
    backend=os.getenv("CELERY_RESULT_BACKEND", "redis://redis:6379/1"),
    # Khai báo package chứa các task để Celery tự động tìm
    include=[
        "app.tasks.audio",           # stub task cũ (ping, process_audio legacy)
        "app.tasks.process_audio",   # task STT mới với full pipeline
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    worker_max_tasks_per_child=10,
    # Fix deprecation warning về broker_connection_retry
    broker_connection_retry_on_startup=True,
)


@celery_app.task(name="ping")
def ping() -> str:
    """Smoke-test task proving the worker is reachable through Redis."""
    return "pong"