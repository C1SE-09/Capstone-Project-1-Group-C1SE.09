"""
tests/test_teacher.py
=====================
Task #59 – Integration tests for POST /api/teacher/voice/upload

Test cases
----------
1. test_upload_valid_m4a           → 201, VoiceRecord with status="pending"
2. test_upload_invalid_extension   → 400 "Unsupported audio format"
3. test_upload_oversized_file      → 413
4. test_upload_saved_with_uuid_filename  → DB row has UUID-based audio_url
"""

from __future__ import annotations

import io
import uuid
from unittest.mock import MagicMock, patch

import pytest
from app.core.database import get_db

# ---------------------------------------------------------------------------
# App + DB session override
# ---------------------------------------------------------------------------
from app.main import app
from fastapi.testclient import TestClient

# Seed IDs that match the DB seed fixtures (same as used in the Flutter test)
TEACHER_ID = uuid.UUID("bbbbbbbb-0000-0000-0000-000000000001")
CLASS_ID   = uuid.UUID("aaaaaaaa-0000-0000-0000-000000000001")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _fake_audio_file(
    filename: str = "recording.m4a",
    size_bytes: int = 1024,
) -> dict:
    """Return files dict compatible with httpx TestClient multipart upload.

    httpx expects: {"field_name": (filename, file_obj, content_type)}
    """
    # Derive a plausible content-type from extension
    ext = filename.rsplit(".", 1)[-1].lower()
    content_types = {
        "m4a": "audio/mp4",
        "wav": "audio/wav",
        "mp3": "audio/mpeg",
        "webm": "audio/webm",
        "exe": "application/octet-stream",
        "txt": "text/plain",
        "pdf": "application/pdf",
        "mp4": "video/mp4",
    }
    ct = content_types.get(ext, "application/octet-stream")
    return {"file": (filename, io.BytesIO(b"0" * size_bytes), ct)}


def _make_form_data(
    teacher_id: str | None = None,
    class_id: str | None = None,
) -> dict:
    return {
        "teacher_id": str(teacher_id or TEACHER_ID),
        "class_id":   str(class_id   or CLASS_ID),
    }


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def mock_db():
    """Return a lightweight mock that satisfies SQLAlchemy Session usage."""
    db = MagicMock()
    db.add    = MagicMock()
    db.commit = MagicMock()

    def fake_refresh(obj):
        # Simulate DB assigning a UUID PK + PENDING status after commit
        obj.voice_record_id = uuid.uuid4()
        from app.models.report import VoiceRecordStatus
        obj.status = VoiceRecordStatus.PENDING

    db.refresh = fake_refresh
    return db


@pytest.fixture()
def client(mock_db):
    """TestClient with DB overridden to the mock and external I/O patched."""
    app.dependency_overrides[get_db] = lambda: mock_db

    with (
        patch(
            "app.api.teacher.upload_audio_to_minio",
            return_value=f"http://minio:9000/audio/teacher_{TEACHER_ID}_abc123.m4a",
        ),
        patch("app.api.teacher._extract_duration_ffprobe", return_value=42.0),
        patch("app.api.teacher.process_audio.delay"),  # don't hit Celery
    ):
        yield TestClient(app)

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

class TestUploadVoiceRecord:
    """POST /api/teacher/voice/upload"""

    # ------------------------------------------------------------------
    # 1. Happy path – valid .m4a → 201 with VoiceRecord
    # ------------------------------------------------------------------
    def test_upload_valid_m4a_returns_201_with_pending_status(self, client):
        resp = client.post(
            "/api/teacher/voice/upload",
            data=_make_form_data(),
            files=_fake_audio_file("lecture.m4a"),
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert "id" in body
        assert body["status"] == "pending"
        # id must be a valid UUID
        uuid.UUID(body["id"])  # raises ValueError if not a valid UUID

    # ------------------------------------------------------------------
    # 2. Invalid extension → 400
    # ------------------------------------------------------------------
    @pytest.mark.parametrize("bad_ext", [".exe", ".txt", ".pdf", ".mp4"])
    def test_upload_invalid_extension_returns_400(self, client, bad_ext):
        resp = client.post(
            "/api/teacher/voice/upload",
            data=_make_form_data(),
            files=_fake_audio_file(f"file{bad_ext}"),
        )
        assert resp.status_code == 400, resp.text
        detail = resp.json().get("detail", "")
        assert "không được hỗ trợ" in detail

    # ------------------------------------------------------------------
    # 3. Oversized file → 413
    # ------------------------------------------------------------------
    def test_upload_oversized_file_returns_413(self, client):
        OVER_25MB = 26 * 1024 * 1024  # 26 MB
        resp = client.post(
            "/api/teacher/voice/upload",
            data=_make_form_data(),
            files=_fake_audio_file("big.m4a", size_bytes=OVER_25MB),
        )
        assert resp.status_code == 413, resp.text

    # ------------------------------------------------------------------
    # 4. audio_url in DB must contain teacher_id UUID
    # ------------------------------------------------------------------
    def test_upload_audio_url_contains_teacher_uuid(self, client, mock_db):
        resp = client.post(
            "/api/teacher/voice/upload",
            data=_make_form_data(),
            files=_fake_audio_file("session.m4a"),
        )
        assert resp.status_code == 201, resp.text
        # The VoiceRecord added to DB should have audio_url set
        call_args = mock_db.add.call_args
        assert call_args is not None, "db.add() was never called"
        voice_record = call_args.args[0]
        assert str(TEACHER_ID) in voice_record.audio_url

    # ------------------------------------------------------------------
    # 5. Other valid audio formats are accepted
    # ------------------------------------------------------------------
    @pytest.mark.parametrize("ext", [".wav", ".mp3", ".webm"])
    def test_upload_other_valid_formats_return_201(self, client, ext):
        resp = client.post(
            "/api/teacher/voice/upload",
            data=_make_form_data(),
            files=_fake_audio_file(f"audio{ext}"),
        )
        assert resp.status_code == 201, resp.text
