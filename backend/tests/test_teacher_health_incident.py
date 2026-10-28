"""
backend/tests/test_teacher_health_incident.py
=============================================
Unit tests cho Task #285 & User Story #74:
- POST  /api/teacher/health-incidents: Báo cáo sự cố khẩn cấp (hỗ trợ 1 chạm / Zero-typing)
- GET   /api/teacher/health-incidents/emergency-contacts/{child_id}: Lấy danh bạ khẩn cấp gọi trực tiếp
- PATCH /api/teacher/health-incidents/{incident_id}: Cập nhật bổ sung biên bản sau khi bé đã ổn định
"""

import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.endpoints.health_incident import router as health_incident_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, Parent, ParentChild
from app.models.device_token import DeviceToken
from app.models.health_incident import HealthIncident
from app.models.user import Teacher, User, UserRole
from app.tasks.incident_notifications import deliver_health_incident_alert

app = FastAPI()
app.include_router(health_incident_router, prefix="/api")

OWN_CLASS_ID = uuid.uuid4()
OTHER_CLASS_ID = uuid.uuid4()
TEACHER_ID = uuid.uuid4()
TEACHER_USER_ID = uuid.uuid4()


@pytest.fixture()
def mock_db():
    return MagicMock()


@pytest.fixture()
def teacher_user():
    return User(
        user_id=TEACHER_USER_ID,
        username="teacher_mai",
        role=UserRole.TEACHER,
        teacher_id=TEACHER_ID,
    )


@pytest.fixture()
def teacher_profile():
    return Teacher(
        teacher_id=TEACHER_ID,
        class_id=OWN_CLASS_ID,
        full_name="Cô Mai",
    )


@pytest.fixture()
def sample_child_and_parents():
    father = Parent(
        parent_id=uuid.uuid4(),
        full_name="Nguyễn Văn Bố",
        phone="0911222333",
        relationship="Bố",
    )
    mother = Parent(
        parent_id=uuid.uuid4(),
        full_name="Trần Thị Mẹ",
        phone="0988777666",
        relationship="Mẹ",
    )
    child = Child(
        child_id=uuid.uuid4(),
        class_id=OWN_CLASS_ID,
        full_name="Nguyễn Văn Bé",
        nickname="Bé Bin",
        avatar_url="https://example.com/bin.jpg",
        parent=father,
    )
    link_father = ParentChild(
        parent_id=father.parent_id,
        child_id=child.child_id,
        parent=father,
        relationship="Bố",
    )
    link_mother = ParentChild(
        parent_id=mother.parent_id,
        child_id=child.child_id,
        parent=mother,
        relationship="Mẹ",
    )
    return child, father, mother, [link_father, link_mother]


def test_create_health_incident_zero_typing_success(
    mock_db, teacher_user, teacher_profile, sample_child_and_parents
):
    """
    [TASK #285] Phát cảnh báo khẩn cấp 1 chạm:
    - Cô chỉ cần chọn loại sự cố (không cần gõ văn bản).
    - Hệ thống tự động sinh mô tả chuẩn.
    - Trả về đầy đủ số điện thoại Bố/Mẹ để cô bấm gọi ngay.
    """
    child, father, mother, links = sample_child_and_parents

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "from child" in q_str:
            return child
        if "from teacher" in q_str:
            return teacher_profile
        return None

    mock_db.scalar.side_effect = mock_scalar_fn
    mock_db.scalars.return_value.all.return_value = links

    client = TestClient(app)
    # Cô chỉ gửi child_id và incident_type (ZERO-TYPING)
    payload = {
        "child_id": str(child.child_id),
        "incident_type": "high_fever",
    }

    with patch("app.api.endpoints.health_incident.send_health_incident_alert_task.delay") as mock_delay:
        response = client.post("/api/teacher/health-incidents", json=payload)

    assert response.status_code == 201
    data = response.json()

    assert data["child_name"] == "Nguyễn Văn Bé"
    assert data["incident_type"] == "high_fever"
    assert data["incident_type_label"] == "Sốt cao"
    # Tự động sinh mô tả khẩn cấp
    assert "Bé sốt cao" in data["description"]
    assert data["reported_by_name"] == "Cô Mai"
    assert mock_db.commit.called
    assert mock_delay.called

    # Kiểm tra danh bạ khẩn cấp trả về có đủ SĐT Bố và Mẹ
    contacts = data["emergency_contacts"]
    assert len(contacts) >= 2
    phones = [c["phone"] for c in contacts]
    assert "0911222333" in phones
    assert "0988777666" in phones


def test_create_health_incident_with_temperature_and_action(
    mock_db, teacher_user, teacher_profile, sample_child_and_parents
):
    """Phát cảnh báo sốt cao kèm nhiệt độ và biện pháp sơ cứu ban đầu."""
    child, father, mother, links = sample_child_and_parents

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "from child" in q_str:
            return child
        if "from teacher" in q_str:
            return teacher_profile
        return None

    mock_db.scalar.side_effect = mock_scalar_fn
    mock_db.scalars.return_value.all.return_value = links

    client = TestClient(app)
    payload = {
        "child_id": str(child.child_id),
        "incident_type": "high_fever",
        "temperature": 39.5,
        "action_taken": "Đã chườm ấm nách và bẹn, cho uống Oresol",
    }

    with patch("app.api.endpoints.health_incident.send_health_incident_alert_task.delay"):
        response = client.post("/api/teacher/health-incidents", json=payload)

    assert response.status_code == 201
    data = response.json()
    assert data["temperature"] == 39.5
    assert "39.5" in data["description"]
    assert data["action_taken"] == "Đã chườm ấm nách và bẹn, cho uống Oresol"


def test_create_health_incident_other_class_forbidden(
    mock_db, teacher_user, teacher_profile
):
    """Giáo viên không được phát cảnh báo cho học sinh lớp khác."""
    other_child = Child(
        child_id=uuid.uuid4(),
        class_id=OTHER_CLASS_ID,
        full_name="Bé lớp khác",
    )

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "from child" in q_str:
            return other_child
        if "from teacher" in q_str:
            return teacher_profile
        return None

    mock_db.scalar.side_effect = mock_scalar_fn

    client = TestClient(app)
    response = client.post(
        "/api/teacher/health-incidents",
        json={"child_id": str(other_child.child_id), "incident_type": "high_fever"},
    )
    assert response.status_code == 403
    assert "không có quyền quản lý" in response.json()["detail"]


def test_get_child_emergency_contacts_direct(
    mock_db, teacher_user, teacher_profile, sample_child_and_parents
):
    """Tra cứu nhanh danh bạ khẩn cấp của bé để cô gọi trực tiếp qua SIM."""
    child, father, mother, links = sample_child_and_parents

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "from child" in q_str:
            return child
        if "from teacher" in q_str:
            return teacher_profile
        return None

    mock_db.scalar.side_effect = mock_scalar_fn
    mock_db.scalars.return_value.all.return_value = links

    client = TestClient(app)
    response = client.get(f"/api/teacher/health-incidents/emergency-contacts/{child.child_id}")

    assert response.status_code == 200
    data = response.json()
    assert data["child_name"] == "Nguyễn Văn Bé"
    assert len(data["emergency_contacts"]) >= 2
    assert any(c["phone"] == "0911222333" for c in data["emergency_contacts"])


def test_update_health_incident_post_emergency(
    mock_db, teacher_user, teacher_profile, sample_child_and_parents
):
    """Bổ sung biên bản chi tiết sự việc sau khi tình hình đã an toàn/ổn định."""
    child, father, mother, links = sample_child_and_parents

    incident = HealthIncident(
        incident_id=uuid.uuid4(),
        child_id=child.child_id,
        class_id=OWN_CLASS_ID,
        reported_by_id=TEACHER_ID,
        incident_type="severe_injury",
        description="Bé bị ngã trầy gối",
        reported_at=datetime.now(timezone.utc),
        child=child,
        reported_by=teacher_profile,
    )

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    def mock_scalar_fn(q):
        q_str = str(q).lower()
        if "from health_incident" in q_str:
            return incident
        if "from teacher" in q_str:
            return teacher_profile
        return None

    mock_db.scalar.side_effect = mock_scalar_fn
    mock_db.scalars.return_value.all.return_value = links

    client = TestClient(app)
    update_payload = {
        "description": "Bé bị ngã trượt chân ở sân chơi, trầy xước nhẹ ở đầu gối phải",
        "action_taken": "Đã sát trùng bằng nước muối sinh lý, dán băng gâu và cho bé uống sữa",
    }
    response = client.patch(f"/api/teacher/health-incidents/{incident.incident_id}", json=update_payload)

    assert response.status_code == 200
    data = response.json()
    assert "trầy xước nhẹ" in data["description"]
    assert "dán băng gâu" in data["action_taken"]
    assert mock_db.commit.called


def test_deliver_health_incident_alert_task(mock_db, sample_child_and_parents, teacher_profile):
    """Kiểm tra push alert khẩn cấp gửi tới phụ huynh có đúng cấu trúc và ưu tiên."""
    child, father, mother, _ = sample_child_and_parents

    incident = HealthIncident(
        incident_id=uuid.uuid4(),
        child_id=child.child_id,
        class_id=OWN_CLASS_ID,
        reported_by_id=TEACHER_ID,
        incident_type="acute_allergy",
        description="Bé nổi mẩn ngứa quanh mặt sau bữa ăn phụ",
        reported_at=datetime(2026, 10, 28, 8, 15, tzinfo=timezone.utc),
        child=child,
        reported_by=teacher_profile,
    )

    device_token = DeviceToken(
        device_token_id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        token="parent_fcm_token_emergency",
    )

    mock_db.scalar.return_value = incident

    with (
        patch("app.tasks.incident_notifications.child_parents_device_tokens", return_value=[device_token]),
        patch("app.tasks.incident_notifications.send_push_notification") as mock_send,
    ):
        result = deliver_health_incident_alert(mock_db, str(incident.incident_id))

        assert result["sent"] == 1
        assert mock_send.called
        call_kwargs = mock_send.call_args.kwargs
        assert call_kwargs["token"] == "parent_fcm_token_emergency"
        assert "KHẨN CẤP" in call_kwargs["title"]
        assert "Nguyễn Văn Bé" in call_kwargs["title"]
        assert "Cô Mai" in call_kwargs["body"]
        assert "Dị ứng cấp tính" in call_kwargs["body"]
        assert call_kwargs["channel_id"] == "kinderlog_emergency"
        assert call_kwargs["data"]["priority"] == "emergency"
