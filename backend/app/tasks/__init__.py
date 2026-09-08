"""
app/tasks/__init__.py
=====================
Package entry-point cho tất cả Celery tasks của ứng dụng KinderLog.

Import các task ở đây để đảm bảo chúng được đăng ký vào Celery registry
khi package được load — quan trọng khi dùng ``celery_app.autodiscover_tasks``
hoặc import trực tiếp từ nơi khác trong project.

Cách dùng
---------
Gửi task từ FastAPI endpoint hoặc bất kỳ đâu trong app:

    from app.tasks import process_audio_task

    process_audio_task.delay(str(voice_record.voice_record_id))

Khởi động worker (giới hạn 2 concurrent STT tasks để tránh GPU OOM):

    celery -A app.tasks.celery_app.celery_app worker \\
        --loglevel=info --concurrency 2 -Q audio
"""

from app.tasks.celery_app import celery_app          # noqa: F401  (re-export)
from app.tasks.process_audio import process_audio_task  # noqa: F401  (register task)

__all__ = [
    "celery_app",
    "process_audio_task",
]
