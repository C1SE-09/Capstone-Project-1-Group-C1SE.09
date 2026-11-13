"""
tests/test_voice_session.py
============================
Tests cho "phiên ghi âm nhiều bản" (multi-clip recording session).

User story: "Giữ nhiều lần ghi âm rồi thực hiện gửi trích xuất một lần".

Test cases
----------
1. merge_transcripts nối transcript của N bản bằng dấu cách (không xuống hàng, bỏ dấu chấm cuối)
2. merge_transcripts bỏ qua bản chưa STT xong (PENDING/PROCESSING/FAILED)
3. merge_transcripts bỏ qua bản có transcript rỗng
4. merge_transcripts giữ thứ tự ghi (created_at tăng dần)
5. merge_transcripts trả chuỗi rỗng khi không có bản nào hợp lệ
6. delete_clip xoá row DB và gọi xoá file MinIO
7. delete_clip trả False khi clip không tồn tại
8. delete_clip ném PermissionError khi teacher khác sở hữu
9. mark_session_merged lưu transcript gộp + bản đại diện + status=merged
10. API: POST /voice/sessions tạo phiên → 201
11. API: GET /voice/sessions trả về danh sách phiên
12. API: GET /voice/sessions/{id} trả chi tiết + clips
13. API: POST /voice/sessions/{id}/merge gộp transcript
14. API: DELETE /voice/{id} xoá bản ghi
15. API: DELETE /voice/sessions/{id} huỷ phiên
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
from app.core.database import get_db
from app.main import app
from app.models.report import (
    VoiceRecordingSession,
    VoiceRecordingSessionStatus,
    VoiceRecord,
    VoiceRecordScope,
    VoiceRecordStatus,
)
from app.services.voice_session_service import (
    attach_clip_to_session,
    delete_clip,
    mark_session_merged,
    merge_transcripts,
)
from fastapi.testclient import TestClient

# ---------------------------------------------------------------------------
# Seed IDs (giống test_teacher.py)
# ---------------------------------------------------------------------------
TEACHER_ID = uuid.UUID("bbbbbbbb-0000-0000-0000-000000000001")
OTHER_TEACHER_ID = uuid.UUID("bbbbbbbb-0000-0000-0000-000000000002")
CLASS_ID = uuid.UUID("aaaaaaaa-0000-0000-0000-000000000001")
CHILD_ID = uuid.UUID("cccccccc-0000-0000-0000-000000000001")

SESSION_ID = uuid.UUID("dddddddd-0000-0000-0000-000000000001")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_clip(
    transcript: str | None = None,
    status: VoiceRecordStatus = VoiceRecordStatus.COMPLETED,
    created_offset: int = 0,
    teacher_id: uuid.UUID = TEACHER_ID,
    clip_order: int | None = None,
) -> VoiceRecord:
    """Tạo 1 VoiceRecord giả lập (không cần DB)."""
    clip = VoiceRecord(
        voice_record_id=uuid.uuid4(),
        teacher_id=teacher_id,
        class_id=CLASS_ID,
        child_id=None,
        audio_url=f"http://minio:9000/audio/clip_{uuid.uuid4()}.m4a",
        audio_duration=30.0,
        file_size_bytes=1024,
        status=status,
        raw_transcript=transcript,
        transcription=transcript,
        clip_order=clip_order,
        recorded_at=datetime.now(timezone.utc).date(),
    )
    # created_at là server_default → gán thủ công để test thứ tự.
    clip.created_at = datetime.now(timezone.utc) + timedelta(seconds=created_offset)
    return clip


def _make_session(clips: list[VoiceRecord]) -> VoiceRecordingSession:
    """Tạo 1 VoiceRecordingSession giả lập với danh sách bản ghi."""
    session = VoiceRecordingSession(
        session_id=SESSION_ID,
        teacher_id=TEACHER_ID,
        class_id=CLASS_ID,
        child_id=None,
        scope=VoiceRecordScope.WHOLE_CLASS,
        status=VoiceRecordingSessionStatus.ACTIVE,
        recorded_at=datetime.now(timezone.utc).date(),
    )
    session.voice_records = clips
    for clip in clips:
        clip.session_id = SESSION_ID
    return session


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture()
def mock_db():
    """Mock DB session đủ dùng cho các endpoint mới."""
    db = MagicMock()
    db.add = MagicMock()
    db.commit = MagicMock()
    db.flush = MagicMock()

    def fake_refresh(obj):
        if not getattr(obj, "session_id", None):
            obj.session_id = uuid.uuid4()
        if not getattr(obj, "created_at", None):
            obj.created_at = datetime.now(timezone.utc)

    db.refresh = fake_refresh
    return db


@pytest.fixture()
def client(mock_db):
    """TestClient với DB override + patch các lời gọi ngoài (MinIO/Celery)."""
    app.dependency_overrides[get_db] = lambda: mock_db

    with (
        patch(
            "app.api.teacher.upload_audio_to_minio",
            return_value="http://minio:9000/audio/clip.m4a",
        ),
        patch("app.api.teacher._extract_duration_ffprobe", return_value=30.0),
        patch("app.api.teacher.dispatch_stt_task", return_value=True),
        patch(
            "app.services.voice_session_service.delete_audio_from_minio",
            return_value=True,
        ),
    ):
        yield TestClient(app)

    app.dependency_overrides.clear()


# ===========================================================================
# Unit tests – merge_transcripts
# ===========================================================================


class TestMergeTranscripts:
    """Gộp transcript của N bản thành 1 text."""

    def test_merges_multiple_clips_with_space(self):
        clips = [
            _make_clip("Bé Lan ăn sáng cháo.", created_offset=0),
            _make_clip("Bé Lan ăn chiều cơm.", created_offset=1),
        ]
        session = _make_session(clips)

        merged = merge_transcripts(session)

        assert merged == "Bé Lan ăn sáng cháo Bé Lan ăn chiều cơm"

    def test_single_clip_returns_its_transcript(self):
        session = _make_session([_make_clip("Chỉ có một bản ghi.")])
        assert merge_transcripts(session) == "Chỉ có một bản ghi"

    def test_skips_clips_not_completed(self):
        clips = [
            _make_clip("Đã xong.", created_offset=0),
            _make_clip("Đang xử lý...", status=VoiceRecordStatus.PROCESSING, created_offset=1),
            _make_clip("Chờ xử lý...", status=VoiceRecordStatus.PENDING, created_offset=2),
            _make_clip("Lỗi", status=VoiceRecordStatus.FAILED, created_offset=3),
        ]
        session = _make_session(clips)

        merged = merge_transcripts(session)

        assert merged == "Đã xong"
        # Các bản lỗi không được làm hỏng cả phiên.
        assert "Đang xử lý" not in merged
        assert "Chờ xử lý" not in merged

    def test_skips_clips_with_empty_transcript(self):
        clips = [
            _make_clip("Nội dung thật.", created_offset=0),
            _make_clip(None, created_offset=1),
            _make_clip("   ", created_offset=2),
        ]
        session = _make_session(clips)

        assert merge_transcripts(session) == "Nội dung thật"

    def test_preserves_recording_order(self):
        clips = [
            _make_clip("Bản thứ ba.", created_offset=20),
            _make_clip("Bản thứ nhất.", created_offset=0),
            _make_clip("Bản thứ hai.", created_offset=10),
        ]
        session = _make_session(clips)

        merged = merge_transcripts(session)

        assert merged == "Bản thứ nhất Bản thứ hai Bản thứ ba"

    def test_clip_order_wins_over_created_at(self):
        """clip_order là nguồn thứ tự chuẩn – created_at có thể trùng nhau."""
        clips = [
            _make_clip("Bản A.", created_offset=0, clip_order=0),
            _make_clip("Bản B.", created_offset=0, clip_order=1),
            _make_clip("Bản C.", created_offset=0, clip_order=2),
        ]
        # Cố tình đảo thứ tự list → clip_order phải thắng.
        session = _make_session(list(reversed(clips)))

        merged = merge_transcripts(session)

        assert merged == "Bản A Bản B Bản C"

    def test_clips_without_clip_order_fall_back_to_created_at(self):
        clips = [
            _make_clip("Cũ nhất.", created_offset=0),
            _make_clip("Mới nhất.", created_offset=10),
        ]
        session = _make_session(clips)

        merged = merge_transcripts(session)

        assert merged == "Cũ nhất Mới nhất"

    def test_returns_empty_string_when_no_valid_clips(self):
        session = _make_session(
            [_make_clip(None, status=VoiceRecordStatus.PENDING)]
        )
        assert merge_transcripts(session) == ""

    def test_edited_transcript_takes_priority_over_raw(self):
        clip = _make_clip("bản raw")
        clip.edited_transcript = "bản đã sửa"
        session = _make_session([clip])

        assert merge_transcripts(session) == "bản đã sửa"


# ===========================================================================
# Unit tests – delete_clip
# ===========================================================================


class TestDeleteClip:
    """Xoá bản ghi (nút X trên thanh ghi âm)."""

    def test_deletes_clip_and_calls_minio(self):
        db = MagicMock()
        clip = _make_clip("nội dung")
        db.query.return_value.filter.return_value.first.return_value = clip

        with patch(
            "app.services.voice_session_service.delete_audio_from_minio",
            return_value=True,
        ) as mock_storage:
            deleted = delete_clip(db, clip.voice_record_id, TEACHER_ID)

        assert deleted is True
        db.delete.assert_called_once_with(clip)
        mock_storage.assert_called_once_with(clip.audio_url)

    def test_returns_false_when_clip_not_found(self):
        db = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = None

        assert delete_clip(db, uuid.uuid4(), TEACHER_ID) is False

    def test_raises_permission_error_for_other_teacher(self):
        db = MagicMock()
        clip = _make_clip("nội dung", teacher_id=OTHER_TEACHER_ID)
        db.query.return_value.filter.return_value.first.return_value = clip

        with pytest.raises(PermissionError):
            delete_clip(db, clip.voice_record_id, TEACHER_ID)

        db.delete.assert_not_called()


# ===========================================================================
# Unit tests – attach_clip_to_session
# ===========================================================================


class TestAttachClip:
    """Gắn bản ghi vào phiên và gán clip_order."""

    def test_assigns_incrementing_clip_order(self):
        db = MagicMock()
        session = _make_session([])
        session.voice_records = []

        clip1 = _make_clip("bản 1")
        clip2 = _make_clip("bản 2")

        attach_clip_to_session(db, clip1, session)
        session.voice_records.append(clip1)

        attach_clip_to_session(db, clip2, session)

        assert clip1.clip_order == 0
        assert clip2.clip_order == 1
        assert clip1.session_id == session.session_id

    def test_clip_order_no_collision_after_delete(self):
        """Xoá bản giữa → bản mới không được trùng clip_order của bản còn lại."""
        db = MagicMock()
        clip1 = _make_clip("bản 1", clip_order=0)
        clip2 = _make_clip("bản 2", clip_order=1)
        clip3 = _make_clip("bản 3", clip_order=2)
        session = _make_session([clip1, clip2, clip3])

        # Xoá bản giữa (clip2) → còn lại clip_order = {0, 2}
        session.voice_records.remove(clip2)

        new_clip = _make_clip("bản mới")
        attach_clip_to_session(db, new_clip, session)

        assert new_clip.clip_order == 3


# ===========================================================================
# Unit tests – mark_session_merged
# ===========================================================================


class TestMarkSessionMerged:
    """Đánh dấu phiên đã gộp."""

    def test_saves_merged_transcript_and_representative(self):
        db = MagicMock()
        session = _make_session([_make_clip("a"), _make_clip("b")])
        representative = session.voice_records[0].voice_record_id

        mark_session_merged(
            db, session, "a\nb", representative_voice_record_id=representative
        )

        assert session.merged_transcript == "a\nb"
        assert session.representative_voice_record_id == representative
        assert session.status == VoiceRecordingSessionStatus.MERGED


# ===========================================================================
# API tests
# ===========================================================================


class TestVoiceSessionApi:
    """Các endpoint phiên ghi âm."""

    # ------------------------------------------------------------------
    # POST /voice/sessions → 201
    # ------------------------------------------------------------------
    def test_create_session_returns_201(self, client):
        session = _make_session([])

        with (
            patch("app.api.teacher.resolve_teacher_id", return_value=TEACHER_ID),
            patch("app.api.teacher.resolve_child_id", return_value=None),
            patch(
                "app.api.teacher.get_or_create_active_session", return_value=session
            ),
        ):
            resp = client.post(
                "/api/teacher/voice/sessions",
                json={
                    "teacher_id": str(TEACHER_ID),
                    "class_id": str(CLASS_ID),
                    "scope": "whole_class",
                },
            )

        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["session_id"] == str(SESSION_ID)
        assert body["status"] == "active"
        assert body["scope"] == "whole_class"
        assert body["clips"] == []

    # ------------------------------------------------------------------
    # POST /voice/sessions → tái dùng phiên ACTIVE (idempotent)
    # ------------------------------------------------------------------
    def test_create_session_reuses_active_session(self, client):
        """Mở lại màn hình ghi âm không được sinh phiên mới."""
        session = _make_session([_make_clip("bản cũ")])

        with (
            patch("app.api.teacher.resolve_teacher_id", return_value=TEACHER_ID),
            patch("app.api.teacher.resolve_child_id", return_value=None),
            patch(
                "app.api.teacher.get_or_create_active_session", return_value=session
            ) as mock_get,
            patch("app.api.teacher.create_session") as mock_new,
        ):
            resp = client.post(
                "/api/teacher/voice/sessions",
                json={
                    "teacher_id": str(TEACHER_ID),
                    "class_id": str(CLASS_ID),
                },
            )

        assert resp.status_code == 201, resp.text
        mock_get.assert_called_once()
        mock_new.assert_not_called()
        # Bản ghi cũ vẫn phải hiện.
        assert len(resp.json()["clips"]) == 1

    # ------------------------------------------------------------------
    # POST /voice/sessions?force_new=true → tạo phiên mới
    # ------------------------------------------------------------------
    def test_create_session_force_new_creates_new_session(self, client):
        session = _make_session([])

        with (
            patch("app.api.teacher.resolve_teacher_id", return_value=TEACHER_ID),
            patch("app.api.teacher.resolve_child_id", return_value=None),
            patch("app.api.teacher.create_session", return_value=session) as mock_new,
            patch(
                "app.api.teacher.get_or_create_active_session"
            ) as mock_get,
        ):
            resp = client.post(
                "/api/teacher/voice/sessions",
                json={
                    "teacher_id": str(TEACHER_ID),
                    "class_id": str(CLASS_ID),
                    "force_new": True,
                },
            )

        assert resp.status_code == 201, resp.text
        mock_new.assert_called_once()
        mock_get.assert_not_called()

    # ------------------------------------------------------------------
    # POST /voice/sessions → 422 khi thiếu field bắt buộc
    # ------------------------------------------------------------------
    def test_create_session_requires_teacher_and_class(self, client):
        resp = client.post("/api/teacher/voice/sessions", json={})
        assert resp.status_code == 422

    # ------------------------------------------------------------------
    # GET /voice/sessions → danh sách phiên
    # ------------------------------------------------------------------
    def test_list_sessions_returns_array(self, client):
        with patch("app.api.teacher.list_sessions", return_value=[]):
            resp = client.get(
                "/api/teacher/voice/sessions",
                params={"teacher_id": str(TEACHER_ID)},
            )

        assert resp.status_code == 200, resp.text
        assert resp.json() == []

    # ------------------------------------------------------------------
    # GET /voice/sessions/{id} → 404 khi không tồn tại
    # ------------------------------------------------------------------
    def test_get_session_returns_404_when_missing(self, client, mock_db):
        mock_db.query.return_value.filter.return_value.first.return_value = None

        resp = client.get(
            f"/api/teacher/voice/sessions/{SESSION_ID}",
            params={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 404

    # ------------------------------------------------------------------
    # GET /voice/sessions/{id} → trả chi tiết + clips
    # ------------------------------------------------------------------
    def test_get_session_returns_clips(self, client, mock_db):
        clip = _make_clip("Bé Lan ăn ngon.")
        session = _make_session([clip])
        mock_db.query.return_value.filter.return_value.first.return_value = session

        resp = client.get(
            f"/api/teacher/voice/sessions/{SESSION_ID}",
            params={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["session_id"] == str(SESSION_ID)
        assert len(body["clips"]) == 1
        assert body["clips"][0]["transcript"] == "Bé Lan ăn ngon."
        assert body["clips"][0]["status"] == "completed"

    # ------------------------------------------------------------------
    # GET /voice/sessions/{id} → pending_count / completed_count
    # ------------------------------------------------------------------
    def test_get_session_counts_pending_and_completed(self, client, mock_db):
        clips = [
            _make_clip("Bản xong.", status=VoiceRecordStatus.COMPLETED),
            _make_clip("Bản đang xử lý.", status=VoiceRecordStatus.PROCESSING),
            _make_clip(None, status=VoiceRecordStatus.PENDING),
        ]
        session = _make_session(clips)
        mock_db.query.return_value.filter.return_value.first.return_value = session

        resp = client.get(
            f"/api/teacher/voice/sessions/{SESSION_ID}",
            params={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["completed_count"] == 1
        assert body["pending_count"] == 2

    # ------------------------------------------------------------------
    # POST /voice/sessions/{id}/merge → gộp transcript
    # ------------------------------------------------------------------
    def test_merge_session_joins_transcripts(self, client, mock_db):
        clip1 = _make_clip("Bản một.", created_offset=0)
        clip2 = _make_clip("Bản hai.", created_offset=1)
        session = _make_session([clip1, clip2])
        mock_db.query.return_value.filter.return_value.first.return_value = session

        resp = client.post(
            f"/api/teacher/voice/sessions/{SESSION_ID}/merge",
            json={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["merged_transcript"] == "Bản một Bản hai"
        assert body["clip_count"] == 2
        assert body["skipped_clips"] == 0
        assert body["representative_voice_record_id"] == str(clip1.voice_record_id)

    # ------------------------------------------------------------------
    # POST /voice/sessions/{id}/merge → 400 khi chưa có transcript nào
    # ------------------------------------------------------------------
    def test_merge_session_returns_400_when_no_transcript(self, client, mock_db):
        clip = _make_clip(None, status=VoiceRecordStatus.PENDING)
        session = _make_session([clip])
        mock_db.query.return_value.filter.return_value.first.return_value = session

        resp = client.post(
            f"/api/teacher/voice/sessions/{SESSION_ID}/merge",
            json={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 400

    # ------------------------------------------------------------------
    # POST /voice/sessions/{id}/merge → 403 khi teacher khác
    # ------------------------------------------------------------------
    def test_merge_session_returns_403_for_other_teacher(self, client, mock_db):
        session = _make_session([_make_clip("nội dung")])
        session.teacher_id = OTHER_TEACHER_ID
        mock_db.query.return_value.filter.return_value.first.return_value = session

        resp = client.post(
            f"/api/teacher/voice/sessions/{SESSION_ID}/merge",
            json={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 403

    # ------------------------------------------------------------------
    # DELETE /voice/{id} → xoá bản ghi
    # ------------------------------------------------------------------
    def test_delete_clip_returns_200(self, client, mock_db):
        clip = _make_clip("nội dung")
        mock_db.query.return_value.filter.return_value.first.return_value = clip

        resp = client.delete(
            f"/api/teacher/voice/{clip.voice_record_id}",
            params={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["deleted"] is True
        assert body["voice_record_id"] == str(clip.voice_record_id)

    # ------------------------------------------------------------------
    # DELETE /voice/{id} → 404 khi không tồn tại
    # ------------------------------------------------------------------
    def test_delete_clip_returns_404_when_missing(self, client, mock_db):
        mock_db.query.return_value.filter.return_value.first.return_value = None

        resp = client.delete(
            f"/api/teacher/voice/{uuid.uuid4()}",
            params={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 404

    # ------------------------------------------------------------------
    # DELETE /voice/{id} → 403 khi teacher khác
    # ------------------------------------------------------------------
    def test_delete_clip_returns_403_for_other_teacher(self, client, mock_db):
        clip = _make_clip("nội dung", teacher_id=OTHER_TEACHER_ID)
        mock_db.query.return_value.filter.return_value.first.return_value = clip

        resp = client.delete(
            f"/api/teacher/voice/{clip.voice_record_id}",
            params={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 403

    # ------------------------------------------------------------------
    # DELETE /voice/sessions/{id} → huỷ phiên
    # ------------------------------------------------------------------
    def test_discard_session_returns_200(self, client, mock_db):
        session = _make_session([_make_clip("nội dung")])
        mock_db.query.return_value.filter.return_value.first.return_value = session

        resp = client.delete(
            f"/api/teacher/voice/sessions/{SESSION_ID}",
            params={"teacher_id": str(TEACHER_ID)},
        )

        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["status"] == "discarded"
        assert body["deleted"] is True


# ===========================================================================
# Route-matching regression
# ===========================================================================


class TestRouteOrdering:
    """Đảm bảo route literal được khai báo trước route có path param."""

    def test_sessions_route_not_shadowed_by_voice_id_route(self, client, mock_db):
        """GET /voice/sessions phải không bị match nhầm vào /voice/{voice_id}."""
        mock_db.query.return_value.filter.return_value.first.return_value = None

        resp = client.get(
            "/api/teacher/voice/sessions",
            params={"teacher_id": str(TEACHER_ID)},
        )

        # 200 (danh sách rỗng) chứ không phải 422 (UUID parse fail)
        assert resp.status_code == 200, resp.text
