"""
tests/test_child_access.py
==========================
Các route cũ trả dữ liệu sức khỏe của bé phải kiểm tra quyền truy cập.
"""

import uuid
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.class_data import router as class_router
from app.api.dashboard import router as dashboard_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child
from app.models.user import Class_, Teacher, User, UserRole

app = FastAPI()
app.include_router(dashboard_router)
app.include_router(class_router)

PARENT_A = uuid.uuid4()
PARENT_B = uuid.uuid4()
OWN_CLASS_ID = uuid.uuid4()
OTHER_CLASS_ID = uuid.uuid4()


def _make_parent(parent_id: uuid.UUID) -> User:
    return User(
        user_id=uuid.uuid4(),
        username="parent.tuan",
        password_hash="x",
        role=UserRole.PARENT,
        parent_id=parent_id,
    )


@pytest.fixture()
def mock_db():
    return MagicMock()


@pytest.fixture()
def parent_user():
    return _make_parent(PARENT_A)


@pytest.fixture()
def teacher_user():
    teacher = Teacher(
        teacher_id=uuid.uuid4(), class_id=OWN_CLASS_ID, full_name="Cô Mai"
    )
    user = User(
        user_id=uuid.uuid4(),
        username="teacher.mai",
        password_hash="x",
        role=UserRole.TEACHER,
        teacher_id=teacher.teacher_id,
    )
    user.teacher = teacher
    return user


@pytest.fixture()
def client(mock_db, parent_user):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: parent_user
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture()
def class_client(mock_db, teacher_user):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_parent_route_rejects_other_parent(client, mock_db):
    mock_db.query.return_value.filter.return_value.first.return_value = _make_parent(
        PARENT_B
    )

    resp = client.get(f"/api/parent/{PARENT_B}")
    assert resp.status_code == 403


def test_parent_child_route_rejects_other_parent(client, mock_db):
    mock_db.query.return_value.filter.return_value.first.return_value = _make_parent(
        PARENT_B
    )

    resp = client.get(f"/api/parent/{PARENT_B}/child")
    assert resp.status_code == 403


def test_class_children_requires_teacher_of_that_class(class_client, mock_db):
    resp = class_client.get(f"/api/class/{OTHER_CLASS_ID}/children")
    assert resp.status_code == 403


def test_class_children_allows_teacher_of_own_class(class_client, mock_db):
    child = Child(
        child_id=uuid.uuid4(),
        class_id=OWN_CLASS_ID,
        full_name="Bé A",
        allergy_status="present",
        medical_allergies="Đậu phộng",
        care_notes="Tránh nắng",
        health_version=2,
    )
    mock_db.query.return_value.filter.return_value.first.return_value = Class_(
        class_id=OWN_CLASS_ID, name="Mầm A"
    )
    mock_db.query.return_value.filter.return_value.order_by.return_value.all.return_value = [
        child
    ]

    resp = class_client.get(f"/api/class/{OWN_CLASS_ID}/children")
    assert resp.status_code == 200, resp.text
    body = resp.json()["children"][0]
    assert body["care_notes"] == "Tránh nắng"
    assert body["health_version"] == 2


def test_class_dashboard_rejects_other_teacher(class_client, mock_db):
    resp = class_client.get(f"/api/class/{OTHER_CLASS_ID}/dashboard")
    assert resp.status_code == 403


def test_class_children_requires_auth(mock_db):
    app.dependency_overrides[get_db] = lambda: mock_db

    resp = TestClient(app).get(f"/api/class/{OWN_CLASS_ID}/children")
    assert resp.status_code == 401
    app.dependency_overrides.clear()
