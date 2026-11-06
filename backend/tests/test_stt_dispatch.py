"""Tests cho cơ chế đảm bảo bản ghi âm luôn được STT xử lý.

Bối cảnh
--------
``process_audio_task.delay(...)`` chỉ đẩy task vào Redis **một lần**. Nếu
worker audio (RunPod) tắt đúng lúc giáo viên upload, task nằm im trong Redis
và bản ghi kẹt ở ``PENDING`` vĩnh viễn.

Module ``stt_dispatch_service`` bổ sung:
- ``dispatch_stt_task``        – đẩy task, bọc try/except (lỗi broker không
  được làm hỏng request upload).
- ``redispatch_stuck_records`` – quét bản ghi kẹt và đẩy lại.
"""

import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models.base import Base
from app.models.report import VoiceRecord, VoiceRecordScope, VoiceRecordStatus
from app.services.stt_dispatch_service import (
    MAX_DISPATCH_ATTEMPTS,
    STUCK_THRESHOLD_SECONDS,
    dispatch_stt_task,
    redispatch_stuck_records,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def db():
    """SQLite in-memory với đủ bảng cần thiết."""
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def _make_record(
    db,
    status: VoiceRecordStatus = VoiceRecordStatus.PENDING,
    created_minutes_ago: int = 10,
    dispatch_attempts: int = 1,
    last_dispatch_minutes_ago: int | None = 10,
) -> VoiceRecord:
    now = datetime.now(timezone.utc)
    record = VoiceRecord(
        voice_record_id=uuid.uuid4(),
        scope=VoiceRecordScope.WHOLE_CLASS,
        audio_url="test.wav",
        status=status,
        stt_dispatch_attempts=dispatch_attempts,
        last_stt_dispatch_at=(
            now - timedelta(minutes=last_dispatch_minutes_ago)
            if last_dispatch_minutes_ago is not None
            else None
        ),
    )
    record.created_at = now - timedelta(minutes=created_minutes_ago)
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


# ---------------------------------------------------------------------------
# dispatch_stt_task
# ---------------------------------------------------------------------------


def test_dispatch_succeeds_and_records_attempt(db):
    """Đẩy task thành công → tăng bộ đếm lần đẩy, lưu mốc thời gian."""
    record = _make_record(db, dispatch_attempts=0)

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.return_value = None
        result = dispatch_stt_task(record.voice_record_id, db=db)

    assert result is True
    mock_task.assert_called_once_with(record.voice_record_id)

    db.refresh(record)
    assert record.stt_dispatch_attempts == 1
    assert record.last_stt_dispatch_at is not None


def test_dispatch_broker_failure_does_not_raise(db):
    """Redis chết giữa chừng → không ném exception (upload vẫn thành công)."""
    record = _make_record(db)

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.side_effect = ConnectionError("Redis down")
        result = dispatch_stt_task(record.voice_record_id, db=db)

    assert result is False
    # Bộ đếm không tăng khi đẩy thất bại → có thể thử lại sau.
    db.refresh(record)
    assert record.stt_dispatch_attempts == 1


def test_dispatch_missing_record_still_queues_task(db):
    """Record không tồn tại → task vẫn được đẩy, chỉ không đếm lần đẩy."""
    fake_id = uuid.uuid4()

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.return_value = None
        result = dispatch_stt_task(fake_id, db=db)

    assert result is True
    mock_task.assert_called_once_with(fake_id)


# ---------------------------------------------------------------------------
# redispatch_stuck_records
# ---------------------------------------------------------------------------


def test_redispatch_skips_recent_pending_records(db):
    """Bản ghi PENDING mới → không đẩy lại (worker có thể đang xử lý)."""
    _make_record(db, created_minutes_ago=1, last_dispatch_minutes_ago=1)

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.return_value = None
        result = redispatch_stuck_records(db=db)

    assert result["redispatched"] == 0
    mock_task.assert_not_called()


def test_redispatch_pushes_stuck_pending_records(db):
    """Bản ghi PENDING quá lâu → được đẩy lại."""
    record = _make_record(
        db,
        created_minutes_ago=60,
        last_dispatch_minutes_ago=60,
    )

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.return_value = None
        result = redispatch_stuck_records(db=db)

    assert result["redispatched"] == 1
    mock_task.assert_called_once_with(record.voice_record_id)

    db.refresh(record)
    assert record.stt_dispatch_attempts == 2


def test_redispatch_ignores_non_pending_statuses(db):
    """Chỉ xử lý PENDING – PROCESSING/COMPLETED/FAILED không đụng vào."""
    for status in (
        VoiceRecordStatus.PROCESSING,
        VoiceRecordStatus.COMPLETED,
        VoiceRecordStatus.FAILED,
    ):
        _make_record(db, status=status, created_minutes_ago=600)

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.return_value = None
        result = redispatch_stuck_records(db=db)

    # Không record PENDING nào → không có gì để quét, không đẩy task nào.
    assert result["redispatched"] == 0
    assert result["scanned"] == 0
    mock_task.assert_not_called()


def test_redispatch_respects_max_attempts(db):
    """Đã đẩy quá số lần tối đa → bỏ qua (không spam queue)."""
    _make_record(
        db,
        created_minutes_ago=600,
        last_dispatch_minutes_ago=600,
        dispatch_attempts=MAX_DISPATCH_ATTEMPTS,
    )

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.return_value = None
        result = redispatch_stuck_records(db=db)

    assert result["redispatched"] == 0
    assert result["skipped"] == 1
    mock_task.assert_not_called()


def test_redispatch_can_filter_by_teacher(db):
    """Lọc theo giáo viên – không đẩy clip của người khác."""
    teacher_a = uuid.uuid4()
    teacher_b = uuid.uuid4()

    rec_a = _make_record(db, created_minutes_ago=600, last_dispatch_minutes_ago=600)
    rec_a.teacher_id = teacher_a
    rec_b = _make_record(db, created_minutes_ago=600, last_dispatch_minutes_ago=600)
    rec_b.teacher_id = teacher_b
    db.commit()

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.return_value = None
        result = redispatch_stuck_records(db=db, teacher_id=teacher_a)

    assert result["redispatched"] == 1
    mock_task.assert_called_once_with(rec_a.voice_record_id)


def test_redispatch_broker_failure_counts_as_skipped(db):
    """Broker chết lúc re-dispatch → bỏ qua, không làm sập cả request."""
    _make_record(db, created_minutes_ago=600, last_dispatch_minutes_ago=600)

    with patch("app.services.stt_dispatch_service.publish_stt_task") as mock_task:
        mock_task.side_effect = ConnectionError("Redis down")
        result = redispatch_stuck_records(db=db)

    assert result["redispatched"] == 0
    assert result["skipped"] == 1


def test_stuck_threshold_is_longer_than_normal_processing(db):
    """Ngưỡng kẹt phải dài hơn thời gian STT bình thường."""
    assert STUCK_THRESHOLD_SECONDS >= 60
    assert STUCK_THRESHOLD_SECONDS <= 600



