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

Khởi động worker (concurrency=1 cho PhoWhisper-large để tránh GPU OOM):

    celery -A app.tasks.celery_app.celery_app worker \\
        --loglevel=info --concurrency 1 -Q audio
"""

from app.tasks.celery_app import celery_app

try:
    from app.tasks.process_audio import process_audio_task
except ImportError:
    process_audio_task = None  # PhoWhisper / CTranslate2 not installed on local host

# LƯU Ý: không import `app.tasks.redispatch_stuck_audio` ở đây.
#
# `redispatch_stuck_audio` phụ thuộc `app.services.stt_dispatch_service`, mà
# service đó import ngược lại `app.tasks.process_audio` → khiến `app.tasks`
# bị import lại giữa chừng (circular import) và task đăng ký sai.
#
# Task vẫn được đăng ký đúng qua `celery_app.conf.include` trong
# `app/tasks/celery_app.py` – Celery tự import module đó khi worker khởi động.

__all__ = [
    "celery_app",
    "process_audio_task",
]
