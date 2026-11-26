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


def test_teacher_owns_class_supports_m2m_teacher_class():
    from app.core.access import teacher_owns_class
    from app.models.user import Teacher, User, UserRole

    primary_class = uuid.uuid4()
    secondary_class = uuid.uuid4()
    other_class = uuid.uuid4()
    teacher_id = uuid.uuid4()

    teacher = Teacher(teacher_id=teacher_id, class_id=primary_class, full_name="Cô Lan")
    user = User(
        user_id=uuid.uuid4(),
        username="colan",
        password_hash="x",
        role=UserRole.TEACHER,
        teacher_id=teacher_id,
    )
    user.teacher = teacher

    # Fast-path lớp chính không cần DB
    assert teacher_owns_class(user, primary_class) is True

    # Lớp thứ 2 qua bảng M2M teacher_class
    fake_db = MagicMock()
    fake_db.execute.return_value.fetchone.return_value = (1,)
    assert teacher_owns_class(user, secondary_class, fake_db) is True

    # Lớp không thuộc quyền
    fake_db.execute.return_value.fetchone.return_value = None
    assert teacher_owns_class(user, other_class, fake_db) is False


def test_class_data_blocks_invalid_uuid_and_teacher_idor():
    from app.core.database import get_db
    from app.core.security import get_current_user
    from app.models.user import Teacher, User, UserRole

    own_class = uuid.uuid4()
    foreign_class = uuid.uuid4()
    teacher_id = uuid.uuid4()
    teacher = Teacher(teacher_id=teacher_id, class_id=own_class, full_name="Cô Mai")
    user = User(
        user_id=uuid.uuid4(),
        username="comai",
        password_hash="x",
        role=UserRole.TEACHER,
        teacher_id=teacher_id,
    )
    user.teacher = teacher

    fake_db = MagicMock()
    fake_db.execute.return_value.fetchone.return_value = None
    app.dependency_overrides[get_db] = lambda: fake_db
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        with TestClient(app) as client:
            assert client.get("/api/class/not-a-uuid").status_code == 404
            assert client.get("/api/class/not-a-uuid/teachers").status_code == 404
            assert client.get(f"/api/class/{foreign_class}").status_code == 403
            assert client.get(f"/api/class/{foreign_class}/teachers").status_code == 403
    finally:
        app.dependency_overrides.clear()


def test_extract_activities_handles_punctuation_only_transcript():
    from app.services import extraction_service

    with (
        patch.object(extraction_service, "_load_model"),
        patch.object(extraction_service, "_tokenizer", return_value=[]),
        patch.object(extraction_service, "_numericalize", return_value=[]),
    ):
        result = extraction_service.extract_from_transcript("... !!! ???")

    assert result == {
        "meals": None,
        "sleeping": None,
        "health": None,
        "activities": None,
        "mood": None,
    }
