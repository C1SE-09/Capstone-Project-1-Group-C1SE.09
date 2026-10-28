"""
backend/tests/test_teacher_medication.py
========================================
Unit tests cho Task #283 & User Story #74:
- GET  /api/teacher/medications/today: Lấy danh sách dặn thuốc của lớp, gom theo sáng/trưa/chiều
- POST /api/teacher/medications/confirm: Xác nhận 1 chạm đã cho uống thuốc
"""

import uuid
from datetime import date, datetime, timezone
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.endpoints.medication import router as medication_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, Parent
from app.models.medication import (
    MedicationLog,
    MedicationRequest,
    MedicationRequestStatus,
)
from app.models.user import Class_, Teacher, User, UserRole

app = FastAPI()
app.include_router(medication_router, prefix="/api")

OWN_CLASS_ID = uuid.uuid4()
OTHER_CLASS_ID = uuid.uuid4()
TEACHER_ID = uuid.uuid4()
TEACHER_USER_ID = uuid.uuid4()


@pytest.fixture()
def mock_db():
    return MagicMock()


@pytest.fixture()
def teacher_user():
    user = User(
        user_id=TEACHER_USER_ID,
        username="teacher_lan",
        role=UserRole.TEACHER,
        teacher_id=TEACHER_ID,
    )
    return user


@pytest.fixture()
def teacher_profile():
    return Teacher(
        teacher_id=TEACHER_ID,
        class_id=OWN_CLASS_ID,
        full_name="Cô Lan",
    )


@pytest.fixture()
def sample_class():
    return Class_(
        class_id=OWN_CLASS_ID,
        name="Lớp Mầm A",
    )


@pytest.fixture()
def sample_child_and_parent():
    parent = Parent(
        parent_id=uuid.uuid4(),
        full_name="Nguyễn Văn Phụ Huynh",
        phone="0912345678",
    )
    child = Child(
        child_id=uuid.uuid4(),
        class_id=OWN_CLASS_ID,
        full_name="Nguyễn Văn Bé",
        nickname="Bé Bo",
        avatar_url="https://example.com/avatar.jpg",
        parent=parent,
    )
    return child, parent


def test_get_medications_today_empty(mock_db, teacher_user, teacher_profile, sample_class):
    """Khi lớp không có đơn dặn thuốc nào -> trả về danh sách rỗng cho 3 buổi."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    mock_db.scalar.side_effect = lambda q: teacher_profile if "teacher" in str(q).lower() else sample_class
    mock_db.scalars.return_value.all.return_value = []

    client = TestClient(app)
    response = client.get("/api/teacher/medications/today?date=2026-10-28")

    assert response.status_code == 200
    data = response.json()
    assert data["class_id"] == str(OWN_CLASS_ID)
    assert data["total_requests"] == 0
    assert data["completed_count"] == 0
    assert data["pending_count"] == 0
    assert data["morning"] == []
    assert data["noon"] == []
    assert data["afternoon"] == []


def test_get_medications_today_grouped_sessions(
    mock_db, teacher_user, teacher_profile, sample_class, sample_child_and_parent
):
    """
    Test nhóm các đơn dặn thuốc theo Sáng, Trưa, Chiều:
    - Bé A: uống sáng + trưa
    - Bé B: uống trưa + chiều
    -> morning: [Bé A]
    -> noon: [Bé A, Bé B]
    -> afternoon: [Bé B]
    """
    child_a, parent_a = sample_child_and_parent

    child_b = Child(
        child_id=uuid.uuid4(),
        class_id=OWN_CLASS_ID,
        full_name="Trần Thị Bé",
        nickname="Bé Bông",
        avatar_url=None,
    )

    req_a = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child_a.child_id,
        class_id=OWN_CLASS_ID,
        medication_name="Kháng sinh Augmentin",
        dosage="5ml",
        instructions="Uống sau ăn no 15 phút",
        sessions=["morning", "noon"],
        start_date=date(2026, 10, 25),
        end_date=date(2026, 10, 30),
        status=MedicationRequestStatus.ACTIVE,
        child=child_a,
        parent=parent_a,
    )

    req_b = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child_b.child_id,
        class_id=OWN_CLASS_ID,
        medication_name="Men vi sinh BioGaia",
        dosage="5 giọt",
        instructions="Nhỏ trực tiếp vào miệng",
        sessions=["noon", "afternoon"],
        start_date=date(2026, 10, 26),
        end_date=date(2026, 10, 29),
        status=MedicationRequestStatus.ACTIVE,
        child=child_b,
        parent=None,
    )

    # Đã có 1 log: Bé A đã được cô Lan cho uống buổi sáng
    log_a_morning = MedicationLog(
        log_id=uuid.uuid4(),
        request_id=req_a.request_id,
        log_date=date(2026, 10, 28),
        session="morning",
        is_given=True,
        given_by_id=TEACHER_ID,
        given_at=datetime(2026, 10, 28, 8, 30, tzinfo=timezone.utc),
        given_by=teacher_profile,
    )

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "teacher" in q_str:
            return teacher_profile
        if "class" in q_str:
            return sample_class
        return None

    mock_db.scalar.side_effect = mock_scalar_fn

    # mock scalars: lần 1 trả requests, lần 2 trả logs
    mock_db.scalars.return_value.all.side_effect = [
        [req_a, req_b],      # requests
        [log_a_morning],     # logs
    ]

    client = TestClient(app)
    response = client.get("/api/teacher/medications/today?date=2026-10-28")

    assert response.status_code == 200
    data = response.json()

    # Kiểm tra số lượng
    # morning: 1 (Bé A)
    # noon: 2 (Bé A + Bé B)
    # afternoon: 1 (Bé B)
    # Total doses = 4; Completed = 1; Pending = 3
    assert data["total_requests"] == 4
    assert data["completed_count"] == 1
    assert data["pending_count"] == 3

    assert len(data["morning"]) == 1
    assert len(data["noon"]) == 2
    assert len(data["afternoon"]) == 1

    # Kiểm tra chi tiết morning của Bé A (đã uống)
    morning_item = data["morning"][0]
    assert morning_item["child_name"] == "Nguyễn Văn Bé"
    assert morning_item["medication_name"] == "Kháng sinh Augmentin"
    assert morning_item["is_given"] is True
    assert morning_item["given_by_name"] == "Cô Lan"
    assert morning_item["parent_phone"] == "0912345678"

    # Kiểm tra noon của Bé A (chưa uống)
    noon_item_a = [item for item in data["noon"] if item["child_name"] == "Nguyễn Văn Bé"][0]
    assert noon_item_a["is_given"] is False
    assert noon_item_a["given_by_name"] is None

    # Kiểm tra afternoon của Bé B (chưa uống)
    afternoon_item = data["afternoon"][0]
    assert afternoon_item["child_name"] == "Trần Thị Bé"
    assert afternoon_item["is_given"] is False


def test_confirm_medication_put_success(
    mock_db, teacher_user, teacher_profile, sample_child_and_parent
):
    """[TASK #284] PUT /api/teacher/medications/{id}/confirm thành công lần đầu."""
    child, parent = sample_child_and_parent
    req = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child.child_id,
        class_id=OWN_CLASS_ID,
        medication_name="Siro ho Prospan",
        dosage="5ml",
        sessions=["morning"],
        start_date=date(2026, 10, 28),
        end_date=date(2026, 10, 28),
        status=MedicationRequestStatus.ACTIVE,
    )

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "from medication_log" in q_str:
            return None  # Chưa có ai cho uống
        if "from medication_request" in q_str:
            return req
        if "from teacher" in q_str:
            return teacher_profile
        return None

    mock_db.scalar.side_effect = mock_scalar_fn

    from unittest.mock import patch

    client = TestClient(app)
    payload = {
        "session": "morning",
        "notes": "Bé uống ngoan không trớ",
    }
    with patch("app.api.endpoints.medication.send_medication_confirmed_notification.delay") as mock_delay:
        response = client.put(f"/api/teacher/medications/{req.request_id}/confirm?date=2026-10-28", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["is_given"] is True
    assert data["session"] == "morning"
    assert data["given_by_name"] == "Cô Lan"
    assert mock_db.commit.called
    assert mock_delay.called


def test_confirm_medication_duplicate_lock_conflict(
    mock_db, teacher_user, teacher_profile, sample_child_and_parent
):
    """
    [TASK #284] Concurrency Locking: Chặn trùng liều khi cô thứ 2 bấm xác nhận.
    Hệ thống phải trả về 409 Conflict và thông báo cô trước đã cho uống lúc mấy giờ.
    """
    child, parent = sample_child_and_parent
    req = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child.child_id,
        class_id=OWN_CLASS_ID,
        medication_name="Hạ sốt Hapacol",
        dosage="1 gói",
        sessions=["noon"],
        start_date=date(2026, 10, 28),
        end_date=date(2026, 10, 28),
        status=MedicationRequestStatus.ACTIVE,
    )

    co_teacher = Teacher(
        teacher_id=uuid.uuid4(),
        class_id=OWN_CLASS_ID,
        full_name="Cô Mai",
    )

    # Đã có log cô Mai cho uống lúc 11:30
    existing_log = MedicationLog(
        log_id=uuid.uuid4(),
        request_id=req.request_id,
        log_date=date(2026, 10, 28),
        session="noon",
        is_given=True,
        given_by_id=co_teacher.teacher_id,
        given_at=datetime(2026, 10, 28, 4, 30, tzinfo=timezone.utc),  # 11:30 UTC+7
        given_by=co_teacher,
    )

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "from medication_log" in q_str:
            return existing_log  # Đã có bản ghi cho uống
        if "from medication_request" in q_str:
            return req
        if "from teacher" in q_str:
            return teacher_profile
        return None

    mock_db.scalar.side_effect = mock_scalar_fn

    client = TestClient(app)
    payload = {
        "session": "noon",
        "notes": "Cô Lan định cho uống lần nữa",
    }
    response = client.put(f"/api/teacher/medications/{req.request_id}/confirm?date=2026-10-28", json=payload)

    # Chặn 409 Conflict!
    assert response.status_code == 409
    detail = response.json()["detail"]
    assert "Cảnh báo trùng liều" in detail
    assert "Cô Mai" in detail
    assert "11:30" in detail


def test_confirm_medication_invalid_session(mock_db, teacher_user, teacher_profile, sample_child_and_parent):
    """Buổi uống không hợp lệ -> 400 Bad Request."""
    child, parent = sample_child_and_parent
    req = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child.child_id,
        class_id=OWN_CLASS_ID,
        medication_name="Thuốc",
        dosage="1 viên",
        sessions=["morning"],
        start_date=date(2026, 10, 28),
        end_date=date(2026, 10, 28),
        status=MedicationRequestStatus.ACTIVE,
    )

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    client = TestClient(app)
    response = client.put(
        f"/api/teacher/medications/{req.request_id}/confirm",
        json={"session": "midnight"},
    )
    assert response.status_code == 400
    assert "Buổi uống không hợp lệ" in response.json()["detail"]


def test_deliver_medication_notification_helper(mock_db, sample_child_and_parent, teacher_profile):
    """Kiểm tra helper gửi push notification tới phụ huynh khi trẻ uống thuốc."""
    from unittest.mock import patch
    from app.models.device_token import DeviceToken
    from app.tasks.medication_notifications import deliver_medication_notification

    child, parent = sample_child_and_parent
    req = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child.child_id,
        class_id=OWN_CLASS_ID,
        medication_name="Kháng sinh Cefixim",
        dosage="5ml",
        sessions=["morning"],
        child=child,
    )
    log = MedicationLog(
        log_id=uuid.uuid4(),
        request_id=req.request_id,
        log_date=date(2026, 10, 28),
        session="morning",
        is_given=True,
        given_by_id=TEACHER_ID,
        given_at=datetime(2026, 10, 28, 1, 30, tzinfo=timezone.utc),  # 08:30 UTC+7
        given_by=teacher_profile,
    )

    device_token = DeviceToken(
        device_token_id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        token="test_fcm_token_123456",
    )

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "from medication_request" in q_str:
            return req
        if "from medication_log" in q_str:
            return log
        return None

    mock_db.scalar.side_effect = mock_scalar_fn

    with (
        patch("app.tasks.medication_notifications.child_parents_device_tokens", return_value=[device_token]),
        patch("app.tasks.medication_notifications.send_push_notification") as mock_send,
    ):
        result = deliver_medication_notification(mock_db, str(req.request_id), str(log.log_id))

        assert result["sent"] == 1
        assert result["removed"] == 0
        assert mock_send.called
        call_kwargs = mock_send.call_args.kwargs
        assert call_kwargs["token"] == "test_fcm_token_123456"
        assert "Nguyễn Văn Bé" in call_kwargs["title"]
        assert "Cô Lan" in call_kwargs["body"]
        assert "Cefixim" in call_kwargs["body"]
        assert "08:30" in call_kwargs["body"]


