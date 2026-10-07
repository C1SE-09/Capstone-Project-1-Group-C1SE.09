"""
tests/test_auth.py
===================
Tests for authentication endpoints including POST /api/auth/change-password
"""

import uuid
from unittest.mock import MagicMock

import pytest
from app.api.endpoints.auth import router as auth_router
from app.core.database import get_db
from app.core.security import get_current_user, hash_password
from app.models.user import User, UserRole
from fastapi import FastAPI
from fastapi.testclient import TestClient

app = FastAPI()
app.include_router(auth_router, prefix="/api")


@pytest.fixture()
def mock_user():
    user = User(
        user_id=uuid.uuid4(),
        username="teacher1",
        password_hash=hash_password("old_password_123"),
        role=UserRole.TEACHER,
    )
    return user


@pytest.fixture()
def mock_db():
    db = MagicMock()
    db.commit = MagicMock()
    return db


@pytest.fixture()
def client(mock_db, mock_user):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: mock_user

    yield TestClient(app)

    app.dependency_overrides.clear()


class TestChangePassword:
    """POST /api/auth/change-password"""

    def test_change_password_success(self, client, mock_user, mock_db):
        payload = {
            "current_password": "old_password_123",
            "new_password": "new_password_456",
        }
        resp = client.post("/api/auth/change-password", json=payload)
        assert resp.status_code == 200, resp.text
        assert resp.json()["message"] == "Đổi mật khẩu thành công!"
        assert mock_db.commit.called

    def test_change_password_wrong_current_password(self, client):
        payload = {
            "current_password": "wrong_password",
            "new_password": "new_password_456",
        }
        resp = client.post("/api/auth/change-password", json=payload)
        assert resp.status_code == 400
        assert resp.json()["detail"] == "Mật khẩu hiện tại không chính xác."

    def test_change_password_same_password(self, client):
        payload = {
            "current_password": "old_password_123",
            "new_password": "old_password_123",
        }
        resp = client.post("/api/auth/change-password", json=payload)
        assert resp.status_code == 400
        assert resp.json()["detail"] == "Mật khẩu mới không được trùng với mật khẩu hiện tại."


class TestChangePasswordUnauthorized:
    """POST /api/auth/change-password without authentication override"""

    def test_unauthorized_access(self, mock_db):
        app.dependency_overrides[get_db] = lambda: mock_db
        # Do not override get_current_user
        test_client = TestClient(app)
        payload = {
            "current_password": "old_password_123",
            "new_password": "new_password_456",
        }
        resp = test_client.post("/api/auth/change-password", json=payload)
        assert resp.status_code == 401
        app.dependency_overrides.clear()
