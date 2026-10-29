"""
tests/test_class_api.py
=======================
Tests cho API quản lý lớp học (school admin):
- GET /api/admin/classes -> 200, liệt kê kèm sĩ số.
- POST /api/admin/classes -> tạo lớp, chặn tên trống / tên trùng.
- PUT /api/admin/classes/{id} -> sửa, chặn tên trùng, chặn sĩ số < số bé hiện tại.
- DELETE /api/admin/classes/{id} -> CHẶN khi còn học sinh, cho xóa khi hết.
- POST /api/admin/classes/batch-delete -> xóa lớp trống, giữ lại lớp còn bé.
"""

import uuid
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.endpoints.admin import router as admin_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child
from app.models.schedule import Room
from app.models.user import Class_, School, Teacher, User, UserRole

app = FastAPI()
app.include_router(admin_router, prefix="/api")

CLASS_ID = uuid.uuid4()
SCHOOL_ID = uuid.uuid4()


def _make_class(name="Lớp Mầm 1"):
    return Class_(
        class_id=CLASS_ID,
        school_id=SCHOOL_ID,
        name=name,
        grade_label="Mầm",
        room_number="P.101",
        capacity=30,
        is_active=True,
    )


@pytest.fixture()
def mock_db():
    db = MagicMock()
    db.commit = MagicMock()
    db.refresh = MagicMock()
    return db


@pytest.fixture()
def admin_user():
    return User(
        user_id=uuid.uuid4(),
        username="admin",
        password_hash="x",
        role=UserRole.ADMIN,
    )


@pytest.fixture()
def admin_client(mock_db, admin_user):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    yield TestClient(app)
    app.dependency_overrides.clear()


def _wire_list(mock_db, classes, counts=None):
    """Giả lập: query(Class_) -> danh sách lớp; query(Child) -> count sĩ số."""
    counts = counts or {}

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            q.filter.return_value.order_by.return_value.all.return_value = classes
            q.filter.return_value.first.side_effect = lambda: None
        elif model is Child:
            q.filter.return_value.count.return_value = counts.get("child", 0)
        elif model is School:
            q.first.return_value = School(school_id=SCHOOL_ID, name="Trường Mầm Non", code="MN01")
        elif model is Teacher:
            q.filter.return_value.update.return_value = 0
        return q

    mock_db.query.side_effect = _query


# ── GET /classes ──────────────────────────────────────────────────────────

def test_list_classes_ok(admin_client, mock_db):
    c = _make_class()
    _wire_list(mock_db, [c], {"child": 12})
    resp = admin_client.get("/api/admin/classes")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert len(body) == 1
    assert body[0]["name"] == "Lớp Mầm 1"
    assert body[0]["student_count"] == 12


# ── POST /classes ─────────────────────────────────────────────────────────

def test_create_class_ok(admin_client, mock_db):
    school = School(school_id=SCHOOL_ID, name="Trường Mầm Non", code="MN01")

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is School:
            q.first.return_value = school
        else:
            q.filter.return_value.first.return_value = None
        return q

    mock_db.query.side_effect = _query
    resp = admin_client.post("/api/admin/classes", json={"name": "Lớp Chồi 1", "capacity": 25})
    assert resp.status_code == 201, resp.text
    assert mock_db.add.called
    assert mock_db.commit.called


def test_create_class_blank_name_rejected(admin_client, mock_db):
    resp = admin_client.post("/api/admin/classes", json={"name": "   "})
    assert resp.status_code == 400, resp.text


def test_create_class_duplicate_name_rejected(admin_client, mock_db):
    existing = _make_class("Lớp Mầm 1")
    school = School(school_id=SCHOOL_ID, name="Trường Mầm Non", code="MN01")

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is School:
            q.first.return_value = school
        elif model is Class_:
            q.filter.return_value.first.return_value = existing
        else:
            q.filter.return_value.first.return_value = None
        return q

    mock_db.query.side_effect = _query
    resp = admin_client.post("/api/admin/classes", json={"name": "Lớp Mầm 1"})
    assert resp.status_code == 400, resp.text
    assert "đã tồn tại" in resp.json()["detail"]


# ── PUT /classes/{id} ─────────────────────────────────────────────────────

def test_update_class_ok(admin_client, mock_db):
    c = _make_class()
    calls = {"n": 0}

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            # Lần 1: lookup theo id -> trả về lớp; lần 2: check trùng tên -> None.
            calls["n"] += 1
            q.filter.return_value.first.return_value = c if calls["n"] == 1 else None
        elif model is Child:
            q.filter.return_value.count.return_value = 0
        return q

    mock_db.query.side_effect = _query
    resp = admin_client.put(f"/api/admin/classes/{CLASS_ID}", json={"name": "Lớp Mầm 2"})
    assert resp.status_code == 200, resp.text
    assert c.name == "Lớp Mầm 2"


def test_update_class_capacity_below_students_rejected(admin_client, mock_db):
    c = _make_class()

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            q.filter.return_value.first.return_value = c
        elif model is Child:
            q.filter.return_value.count.return_value = 20
        return q

    mock_db.query.side_effect = _query
    resp = admin_client.put(f"/api/admin/classes/{CLASS_ID}", json={"capacity": 10})
    assert resp.status_code == 400, resp.text


def test_update_class_can_clear_capacity(admin_client, mock_db):
    """Bỏ trống sĩ số tối đa -> phải xóa được (set NULL), không phải giữ giá trị cũ."""
    c = _make_class()

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            q.filter.return_value.first.return_value = c
        elif model is Child:
            q.filter.return_value.count.return_value = 20
        return q

    mock_db.query.side_effect = _query
    resp = admin_client.put(f"/api/admin/classes/{CLASS_ID}", json={"capacity": None})
    assert resp.status_code == 200, resp.text
    assert c.capacity is None


def test_update_class_can_clear_grade_and_room(admin_client, mock_db):
    """Bỏ trống khối/phòng -> phải xóa được."""
    c = _make_class()

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            q.filter.return_value.first.return_value = c
        elif model is Child:
            q.filter.return_value.count.return_value = 0
        return q

    mock_db.query.side_effect = _query
    resp = admin_client.put(
        f"/api/admin/classes/{CLASS_ID}",
        json={"grade_label": None, "room_number": None},
    )
    assert resp.status_code == 200, resp.text
    assert c.grade_label is None
    assert c.room_number is None


def test_update_class_omitting_capacity_keeps_old_value(admin_client, mock_db):
    """Không gửi field capacity -> giữ nguyên sĩ số cũ."""
    c = _make_class()

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            calls = getattr(_query, "calls", {"n": 0})
            _query.calls = calls
            calls["n"] += 1
            q.filter.return_value.first.return_value = c if calls["n"] == 1 else None
        elif model is Child:
            q.filter.return_value.count.return_value = 0
        return q

    mock_db.query.side_effect = _query
    resp = admin_client.put(f"/api/admin/classes/{CLASS_ID}", json={"name": "Lớp Mầm 2"})
    assert resp.status_code == 200, resp.text
    assert c.capacity == 30


# ── DELETE /classes/{id} ──────────────────────────────────────────────────

def test_delete_class_blocked_when_has_students(admin_client, mock_db):
    """Quy tắc: còn học sinh thì KHÔNG cho xóa."""
    c = _make_class()

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            q.filter.return_value.first.return_value = c
        elif model is Child:
            q.filter.return_value.count.return_value = 5
        return q

    mock_db.query.side_effect = _query
    resp = admin_client.delete(f"/api/admin/classes/{CLASS_ID}")
    assert resp.status_code == 400, resp.text
    assert "còn 5 học sinh" in resp.json()["detail"]
    assert c.is_active is True


def test_delete_class_ok_when_empty(admin_client, mock_db):
    c = _make_class()

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            q.filter.return_value.first.return_value = c
        elif model is Child:
            q.filter.return_value.count.return_value = 0
        elif model is Teacher:
            q.filter.return_value.update.return_value = 0
        return q

    mock_db.query.side_effect = _query
    mock_db.execute = MagicMock()
    resp = admin_client.delete(f"/api/admin/classes/{CLASS_ID}")
    assert resp.status_code == 200, resp.text
    assert c.is_active is False


# ── POST /classes/batch-delete ────────────────────────────────────────────

def test_batch_delete_keeps_classes_with_students(admin_client, mock_db):
    full = _make_class("Lớp Mầm 1")
    empty_id = uuid.uuid4()
    empty = Class_(
        class_id=empty_id, school_id=SCHOOL_ID, name="Lớp Chồi 1", is_active=True,
    )

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            calls = getattr(_query, "calls", {"n": 0})
            _query.calls = calls
            calls["n"] += 1
            q.filter.return_value.first.return_value = full if calls["n"] == 1 else empty
        elif model is Child:
            # lớp đầu còn 3 bé, lớp sau hết
            q.filter.return_value.count.side_effect = None
            q.filter.return_value.count.return_value = 0
            counts = getattr(_query, "counts", {"n": 0})
            _query.counts = counts
            counts["n"] += 1
            q.filter.return_value.count.return_value = 3 if counts["n"] == 1 else 0
        elif model is Teacher:
            q.filter.return_value.update.return_value = 0
        elif model is Room:
            q.filter.return_value.update.return_value = 0
        return q

    mock_db.query.side_effect = _query
    mock_db.execute = MagicMock()
    resp = admin_client.post(
        "/api/admin/classes/batch-delete",
        json={"ids": [str(CLASS_ID), str(empty_id)]},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["deleted_count"] == 1
    assert len(body["blocked"]) == 1
    assert full.is_active is True
    assert empty.is_active is False
