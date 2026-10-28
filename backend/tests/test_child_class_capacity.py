"""
tests/test_child_class_capacity.py
===================================
Test validate sĩ số lớp khi gán học sinh:
- POST /api/admin/children -> chặn lớp đầy, chặn lớp không tồn tại.
- PUT  /api/admin/children/{id} -> chặn chuyển vào lớp đầy,
  cho giữ nguyên lớp cũ kể cả lớp đã đầy.
- Validate họ tên / biệt danh / giới tính / trạng thái.
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
from app.models.user import Class_, User, UserRole

app = FastAPI()
app.include_router(admin_router, prefix="/api")

CLASS_ID = uuid.uuid4()
OTHER_CLASS_ID = uuid.uuid4()
SCHOOL_ID = uuid.uuid4()


def _make_class(capacity=5, name="Lớp Mầm 1", class_id=CLASS_ID):
    return Class_(
        class_id=class_id,
        school_id=SCHOOL_ID,
        name=name,
        grade_label="Mầm",
        room_number="P.101",
        capacity=capacity,
        is_active=True,
    )


@pytest.fixture()
def mock_db():
    db = MagicMock()
    db.commit = MagicMock()
    db.refresh = MagicMock()
    db.flush = MagicMock()
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


def _wire_class_query(mock_db, classroom, student_count):
    """query(Class_) -> classroom; query(Child) -> count sĩ số."""

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Class_:
            q.filter.return_value.first.return_value = classroom
        elif model is Child:
            q.filter.return_value.count.return_value = student_count
        return q

    mock_db.query.side_effect = _query


# ── POST /children: chặn lớp đầy sĩ số ───────────────────────────────────

def test_create_child_blocked_when_class_full(admin_client, mock_db):
    """Lớp đã đầy sĩ số -> 400, không tạo học sinh."""
    _wire_class_query(mock_db, _make_class(capacity=5), student_count=5)

    resp = admin_client.post(
        "/api/admin/children",
        json={"full_name": "Bé Mới", "class_id": str(CLASS_ID)},
    )

    assert resp.status_code == 400, resp.text
    assert "đầy sĩ số" in resp.json()["detail"]
    assert not mock_db.add.called


def test_create_child_blocked_when_class_not_found(admin_client, mock_db):
    """class_id không tồn tại -> 404."""
    _wire_class_query(mock_db, None, student_count=0)

    resp = admin_client.post(
        "/api/admin/children",
        json={"full_name": "Bé Mới", "class_id": str(CLASS_ID)},
    )

    assert resp.status_code == 404, resp.text
    assert not mock_db.add.called


def test_create_child_allowed_when_class_has_room(admin_client, mock_db):
    """Lớp còn chỗ -> tạo học sinh thành công."""
    _wire_class_query(mock_db, _make_class(capacity=5), student_count=3)

    resp = admin_client.post(
        "/api/admin/children",
        json={"full_name": "Bé Mới", "class_id": str(CLASS_ID)},
    )

    assert resp.status_code == 201, resp.text
    assert mock_db.add.called


def test_create_child_allowed_when_no_capacity_limit(admin_client, mock_db):
    """capacity = None -> không giới hạn sĩ số, vẫn tạo được."""
    _wire_class_query(mock_db, _make_class(capacity=None), student_count=99)

    resp = admin_client.post(
        "/api/admin/children",
        json={"full_name": "Bé Mới", "class_id": str(CLASS_ID)},
    )

    assert resp.status_code == 201, resp.text
    assert mock_db.add.called


def test_create_child_without_class_id_not_auto_assigned(admin_client, mock_db):
    """Không truyền class_id -> học sinh chưa xếp lớp, KHÔNG tự gán lớp đầu tiên."""
    resp = admin_client.post("/api/admin/children", json={"full_name": "Bé Mới"})

    assert resp.status_code == 201, resp.text
    assert mock_db.add.called
    added_child = mock_db.add.call_args[0][0]
    assert added_child.class_id is None


def test_create_child_invalid_class_id_returns_400(admin_client, mock_db):
    """class_id sai định dạng -> 400 (không phải lỗi 500)."""
    resp = admin_client.post(
        "/api/admin/children",
        json={"full_name": "Bé Mới", "class_id": "không-phải-uuid"},
    )

    assert resp.status_code == 400, resp.text
    assert not mock_db.add.called


# ── PUT /children/{id}: chặn chuyển vào lớp đầy ────────────────────────────

def test_update_child_blocked_when_moving_to_full_class(admin_client, mock_db):
    """Chuyển bé sang lớp đã đầy -> 400, giữ nguyên lớp cũ."""
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        class_id=OTHER_CLASS_ID,
        gender="male",
    )
    classroom = _make_class(capacity=5)

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
            # Lớp đích có 5 bé / capacity 5 -> đầy
            q.filter.return_value.count.return_value = 5
        elif model is Class_:
            q.filter.return_value.first.return_value = classroom
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}",
        json={"class_id": str(CLASS_ID)},
    )

    assert resp.status_code == 400, resp.text
    assert "đầy sĩ số" in resp.json()["detail"]
    assert child.class_id == OTHER_CLASS_ID


def test_update_child_allowed_when_moving_to_class_with_room(admin_client, mock_db):
    """Chuyển bé sang lớp còn chỗ -> OK."""
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        class_id=OTHER_CLASS_ID,
        gender="male",
    )
    classroom = _make_class(capacity=5)

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
            q.filter.return_value.count.return_value = 3  # còn chỗ
        elif model is Class_:
            q.filter.return_value.first.return_value = classroom
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}",
        json={"class_id": str(CLASS_ID)},
    )

    assert resp.status_code == 200, resp.text
    assert child.class_id == CLASS_ID


def test_update_child_keeps_same_full_class(admin_client, mock_db):
    """Giữ nguyên lớp đã đầy (bé đang ở đó) -> OK, không bị chặn oan."""
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        class_id=CLASS_ID,
        gender="male",
    )

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
        elif model is Class_:
            q.filter.return_value.first.return_value = _make_class(capacity=5)
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}",
        json={"class_id": str(CLASS_ID)},
    )

    assert resp.status_code == 200, resp.text
    assert child.class_id == CLASS_ID


def test_update_child_can_remove_from_class(admin_client, mock_db):
    """Bỏ lớp (class_id rỗng) -> được phép, không check sĩ số."""
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        class_id=CLASS_ID,
        gender="male",
    )

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}",
        json={"class_id": ""},
    )

    assert resp.status_code == 200, resp.text
    assert child.class_id is None


# ── Validate hồ sơ học sinh ──────────────────────────────────────────────

def test_update_child_blank_name_rejected(admin_client, mock_db):
    child = Child(child_id=uuid.uuid4(), full_name="Bé A", gender="male")

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}", json={"full_name": "   "}
    )

    assert resp.status_code == 400, resp.text
    assert "Họ tên" in resp.json()["detail"]


def test_update_child_invalid_gender_rejected(admin_client, mock_db):
    child = Child(child_id=uuid.uuid4(), full_name="Bé A", gender="male")

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}", json={"gender": "xyz"}
    )

    assert resp.status_code == 400, resp.text
    assert "Giới tính" in resp.json()["detail"]


def test_update_child_status_is_applied(admin_client, mock_db):
    """Trạng thái gửi lên phải được lưu (trước đây bị bỏ qua)."""
    child = Child(child_id=uuid.uuid4(), full_name="Bé A", gender="male")

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}", json={"status": "withdrawn"}
    )

    assert resp.status_code == 200, resp.text
    assert child.status.value == "withdrawn"


def test_update_child_invalid_status_rejected(admin_client, mock_db):
    child = Child(child_id=uuid.uuid4(), full_name="Bé A", gender="male")

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}", json={"status": "transferred"}
    )

    assert resp.status_code == 400, resp.text
    assert "Trạng thái" in resp.json()["detail"]


def test_update_child_invalid_child_id_returns_400(admin_client, mock_db):
    """ID học sinh sai định dạng -> 400 (không phải lỗi 500)."""
    resp = admin_client.put("/api/admin/children/khong-phai-uuid", json={"full_name": "Bé A"})

    assert resp.status_code == 400, resp.text


# ── Xoá được giá trị optional (gửi null) ─────────────────────────────────

def test_update_child_can_clear_nickname(admin_client, mock_db):
    """Bỏ trống biệt danh -> phải xoá được (set NULL)."""
    child = Child(child_id=uuid.uuid4(), full_name="Bé A", nickname="Bé Bờm", gender="male")

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}", json={"nickname": None}
    )

    assert resp.status_code == 200, resp.text
    assert child.nickname is None


def test_update_child_omitting_nickname_keeps_value(admin_client, mock_db):
    """Không gửi field nickname -> giữ nguyên biệt danh cũ."""
    child = Child(child_id=uuid.uuid4(), full_name="Bé A", nickname="Bé Bờm", gender="male")

    def _query(model, *args, **kwargs):
        q = MagicMock()
        if model is Child:
            q.filter.return_value.first.return_value = child
        return q

    mock_db.query.side_effect = _query

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}", json={"full_name": "Bé A2"}
    )

    assert resp.status_code == 200, resp.text
    assert child.nickname == "Bé Bờm"
    assert child.full_name == "Bé A2"
