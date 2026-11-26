"""Unit tests cho /api/health và idempotency của process_audio_task."""

import uuid
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app.main import app
from app.models.report import VoiceRecord, VoiceRecordStatus
from app.tasks.process_audio import process_audio_task


def test_health_check_ok_when_db_and_redis_healthy():
    fake_db = MagicMock()
    fake_redis = MagicMock()
    fake_redis.ping.return_value = True

    with (
        patch("app.main.SessionLocal", return_value=fake_db),
        patch("app.main.get_redis_client", return_value=fake_redis),
    ):
        with TestClient(app) as client:
            resp = client.get("/api/health")

    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["checks"] == {"database": "ok", "redis": "ok"}
    fake_db.close.assert_called_once()


def test_health_check_returns_503_when_redis_down():
    fake_db = MagicMock()
    fake_redis = MagicMock()
    fake_redis.ping.side_effect = ConnectionError("redis unreachable")

    with (
        patch("app.main.SessionLocal", return_value=fake_db),
        patch("app.main.get_redis_client", return_value=fake_redis),
    ):
        with TestClient(app) as client:
            resp = client.get("/api/health")

    assert resp.status_code == 503
    body = resp.json()
    assert body["status"] == "degraded"
    assert body["checks"] == {"database": "ok", "redis": "error"}
    fake_db.close.assert_called_once()


def test_process_audio_task_skips_already_completed_record():
    record_id = uuid.uuid4()
    completed_record = VoiceRecord(
        voice_record_id=record_id,
        status=VoiceRecordStatus.COMPLETED,
        raw_transcript="Bé An ăn hết suất cơm.",
        edited_transcript="Bé An ăn rất ngoan.",
        extraction_result={"eating": "ăn rất ngoan"},
    )
    fake_db = MagicMock()
    fake_db.get.return_value = completed_record

    with (
        patch("app.tasks.process_audio.SessionLocal", return_value=fake_db),
        patch("app.tasks.process_audio._download_audio") as mock_download,
    ):
        result = process_audio_task(str(record_id))

    assert result["skipped_duplicate"] is True
    assert completed_record.edited_transcript == "Bé An ăn rất ngoan."
    assert completed_record.extraction_result == {"eating": "ăn rất ngoan"}
    mock_download.assert_not_called()
    fake_db.close.assert_called_once()
