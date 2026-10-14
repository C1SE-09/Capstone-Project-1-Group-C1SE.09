"""
tests/test_parent_api.py
========================
Tests cho API phụ huynh self-service:
- GET /api/parent/{id} trả về trường relationship
- PUT /api/parent/{id} cập nhật số điện thoại (auth-scoped)
"""

import uuid
from unittest.mock import MagicMock

import pytest
from app.api.dashboard import router as dashboard_router
from app.api.parent import router as parent_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Parent
from app.models.user import User, UserRole
from fastapi import FastAPI
from fastapi.testclient import TestClient

app = FastAPI()
app.include_router(dashboard_router)
app.include_router(parent_router)

PARENT_A = uuid.uuid4()
PARENT_B = uuid.uuid4()


def _make_parent(parent_id: uuid.UUID, phone: str = "0912000001") -> Parent:
    parent = Parent(
        parent_id=parent_id,
        full_name="Trần Văn Tuấn",
        phone=phone,
        email="parent.tuan@gmail.com",
    )
    # Gán instance attr để test chạy được trước khi model có cột relationship
    parent.relationship_ = "Bố"
    return parent


@pytest.fixture()
def parent_user():
    return User(
        user_id=uuid.uuid4(),
        username="parent.tuan",
        password_hash="x",
        role=UserRole.PARENT,
        parent_id=PARENT_A,
    )


@pytest.fixture()
def admin_user():
    return User(
        user_id=uuid.uuid4(),
        username="admin",
        password_hash="x",
        role=UserRole.ADMIN,
    )


@pytest.fixture()
def mock_db():
    db = MagicMock()
    db.commit = MagicMock()
    return db


@pytest.fixture()
def client(mock_db, parent_user):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: parent_user
    yield TestClient(app)
    app.dependency_overrides.clear()


class TestGetParent:
    """GET /api/parent/{id}"""

    def test_get_parent_returns_relationship(self, client, mock_db):
        parent = _make_parent(PARENT_A)
        mock_db.query.return_value.filter.return_value.first.return_value = parent
        resp = client.get(f"/api/parent/{PARENT_A}")
        assert resp.status_code == 200, resp.text
        assert resp.json().get("relationship") == "Bố"


class TestUpdateParentPhone:
    """PUT /api/parent/{id}"""

    def test_update_own_phone_success(self, client, mock_db):
        parent = _make_parent(PARENT_A)
        mock_db.query.return_value.filter.return_value.first.side_effect = [
            parent,  # lookup theo id
            None,  # kiểm tra SĐT trùng
        ]
        resp = client.put(f"/api/parent/{PARENT_A}", json={"phone": "0987654321"})
        assert resp.status_code == 200, resp.text
        assert parent.phone == "0987654321"
        assert mock_db.commit.called

    def test_update_other_parent_forbidden(self, client):
        resp = client.put(f"/api/parent/{PARENT_B}", json={"phone": "0987654321"})
        assert resp.status_code == 403

    def test_update_invalid_phone_rejected(self, client):
        resp = client.put(f"/api/parent/{PARENT_A}", json={"phone": "12345"})
        assert resp.status_code == 422

    def test_update_duplicate_phone_conflict(self, client, mock_db):
        parent = _make_parent(PARENT_A)
        other = _make_parent(PARENT_B, phone="0987654321")
        mock_db.query.return_value.filter.return_value.first.side_effect = [
            parent,  # lookup theo id
            other,  # SĐT đã tồn tại ở parent khác
        ]
        resp = client.put(f"/api/parent/{PARENT_A}", json={"phone": "0987654321"})
        assert resp.status_code == 409
        assert not mock_db.commit.called

    def test_update_missing_parent_404(self, client, mock_db):
        mock_db.query.return_value.filter.return_value.first.side_effect = [None]
        resp = client.put(f"/api/parent/{PARENT_A}", json={"phone": "0987654321"})
        assert resp.status_code == 404

    def test_admin_can_update_any_parent(self, client, mock_db, admin_user):
        app.dependency_overrides[get_current_user] = lambda: admin_user
        parent = _make_parent(PARENT_B, phone="0912000002")
        mock_db.query.return_value.filter.return_value.first.side_effect = [
            parent,
            None,
        ]
        resp = client.put(f"/api/parent/{PARENT_B}", json={"phone": "0987654321"})
        assert resp.status_code == 200, resp.text
        assert parent.phone == "0987654321"

    def test_update_requires_auth(self, mock_db):
        app.dependency_overrides[get_db] = lambda: mock_db
        # Không override get_current_user → phải 401
        test_client = TestClient(app)
        resp = test_client.put(f"/api/parent/{PARENT_A}", json={"phone": "0987654321"})
        assert resp.status_code == 401
        app.dependency_overrides.clear()
