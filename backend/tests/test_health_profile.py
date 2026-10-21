"""
tests/test_health_profile.py
============================
Tests cho US "Cập nhật sức khỏe": quy tắc chuẩn hóa dữ liệu sức khỏe,
phân quyền truy cập hồ sơ bé và API GET/PATCH /api/children/{id}/health-profile.
"""

import uuid
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.api.child_health import router as child_health_router
from app.api.endpoints.admin import router as admin_router
from app.core.access import resolve_child_for_actor
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ParentChild
from app.models.user import Teacher, User, UserRole
from app.services.health_profile_service import (
    apply_health_patch,
    classify_legacy_allergy,
    ensure_within_limits,
    normalize_health_values,
)


@pytest.mark.parametrize(
    "raw,expected",
    [
        (None, "unknown"),
        ("", "unknown"),
        ("   ", "unknown"),
        ("không có", "none"),
        (" KHÔNG ", "none"),
        ("None", "none"),
        ("Không dung nạp lactose", "present"),
        ("Đậu phộng", "present"),
    ],
)
def test_classify_legacy_allergy(raw, expected):
    assert classify_legacy_allergy(raw) == expected


def test_normalize_clears_allergy_text_when_none():
    assert normalize_health_values(
        allergy_status="none",
        medical_allergies="Đậu phộng",
        care_notes="  ",
    ) == {"allergy_status": "none", "medical_allergies": None, "care_notes": None}


def test_normalize_requires_text_when_present():
    with pytest.raises(HTTPException) as exc:
        normalize_health_values(
            allergy_status="present",
            medical_allergies="   ",
            care_notes=None,
        )
    assert exc.value.status_code == 422


def test_normalize_rejects_unknown_status():
    with pytest.raises(HTTPException) as exc:
        normalize_health_values(
            allergy_status="yes", medical_allergies=None, care_notes=None
        )
    assert exc.value.status_code == 422


def test_ensure_within_limits_rejects_long_text():
    with pytest.raises(HTTPException) as exc:
        ensure_within_limits(medical_allergies="a" * 1001, care_notes=None)
    assert exc.value.status_code == 422


def test_ensure_within_limits_accepts_exactly_1000():
    ensure_within_limits(medical_allergies="a" * 1000, care_notes="b" * 1000)


def test_unchanged_legacy_text_longer_than_limit_is_allowed():
    # Dữ liệu cũ dài hơn 1000 vẫn giữ nguyên khi phụ huynh chỉ sửa field khác.
    actor = User(
        user_id=uuid.uuid4(),
        username="parent",
        password_hash="x",
        role=UserRole.PARENT,
    )
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        allergy_status="present",
        medical_allergies="a" * 1500,
        health_version=1,
    )
    db = MagicMock()
    db.query.return_value.filter.return_value.update.return_value = 1

    assert apply_health_patch(db, child, {"care_notes": "Tránh nắng"}, 1, actor) is child
    payload = db.query.return_value.filter.return_value.update.call_args.args[0]
    assert payload["medical_allergies"] == "a" * 1500


def test_patch_noop_does_not_bump_version():
    actor = User(
        user_id=uuid.uuid4(),
        username="parent",
        password_hash="x",
        role=UserRole.PARENT,
    )
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        allergy_status="none",
        medical_allergies=None,
        care_notes="Tránh nắng",
        health_version=3,
    )
    db = MagicMock()

    assert apply_health_patch(db, child, {"care_notes": " Tránh nắng "}, 3, actor) is child
    assert not db.query.return_value.filter.return_value.update.called


def test_patch_stale_version_raises_409():
    actor = User(
        user_id=uuid.uuid4(),
        username="parent",
        password_hash="x",
        role=UserRole.PARENT,
    )
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        allergy_status="unknown",
        health_version=2,
    )
    db = MagicMock()
    db.query.return_value.filter.return_value.update.return_value = 0

    with pytest.raises(HTTPException) as exc:
        apply_health_patch(db, child, {"allergy_status": "none"}, 1, actor)
    assert exc.value.status_code == 409
    assert db.rollback.called


def test_parent_cannot_access_other_child():
    parent_a, parent_b = uuid.uuid4(), uuid.uuid4()
    child = Child(child_id=uuid.uuid4(), parent_id=parent_b, full_name="Bé B")
    user = User(
        user_id=uuid.uuid4(),
        username="a",
        password_hash="x",
        role=UserRole.PARENT,
        parent_id=parent_a,
    )
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = child

    with pytest.raises(HTTPException) as exc:
        resolve_child_for_actor(db, child.child_id, user)
    assert exc.value.status_code == 403


def test_parent_linked_via_parent_child_can_access():
    parent_id = uuid.uuid4()
    child = Child(child_id=uuid.uuid4(), full_name="Bé A")
    child.parent_links.append(
        ParentChild(parent_id=parent_id, child_id=child.child_id)
    )
    user = User(
        user_id=uuid.uuid4(),
        username="a",
        password_hash="x",
        role=UserRole.PARENT,
        parent_id=parent_id,
    )
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = child

    assert resolve_child_for_actor(db, child.child_id, user) is child


def test_teacher_can_access_child_of_own_class():
    class_id = uuid.uuid4()
    teacher = Teacher(teacher_id=uuid.uuid4(), class_id=class_id, full_name="Cô Mai")
    user = User(
        user_id=uuid.uuid4(),
        username="t",
        password_hash="x",
        role=UserRole.TEACHER,
        teacher_id=teacher.teacher_id,
    )
    user.teacher = teacher
    child = Child(child_id=uuid.uuid4(), class_id=class_id, full_name="Bé A")
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = child

    assert resolve_child_for_actor(db, child.child_id, user) is child


def test_teacher_cannot_access_child_of_other_class():
    teacher = Teacher(teacher_id=uuid.uuid4(), class_id=uuid.uuid4(), full_name="Cô Mai")
    user = User(
        user_id=uuid.uuid4(),
        username="t",
        password_hash="x",
        role=UserRole.TEACHER,
        teacher_id=teacher.teacher_id,
    )
    user.teacher = teacher
    child = Child(child_id=uuid.uuid4(), class_id=uuid.uuid4(), full_name="Bé B")
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = child

    with pytest.raises(HTTPException) as exc:
        resolve_child_for_actor(db, child.child_id, user)
    assert exc.value.status_code == 403


def test_admin_can_access_any_child():
    user = User(
        user_id=uuid.uuid4(),
        username="admin",
        password_hash="x",
        role=UserRole.ADMIN,
    )
    child = Child(child_id=uuid.uuid4(), full_name="Bé A")
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = child

    assert resolve_child_for_actor(db, child.child_id, user) is child


def test_missing_child_returns_404():
    user = User(
        user_id=uuid.uuid4(),
        username="admin",
        password_hash="x",
        role=UserRole.ADMIN,
    )
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = None

    with pytest.raises(HTTPException) as exc:
        resolve_child_for_actor(db, uuid.uuid4(), user)
    assert exc.value.status_code == 404


# ---------------------------------------------------------------------------
# API GET/PATCH /api/children/{child_id}/health-profile
# ---------------------------------------------------------------------------

app = FastAPI()
app.include_router(child_health_router)

PARENT_A = uuid.uuid4()


@pytest.fixture()
def mock_db():
    db = MagicMock()
    db.commit = MagicMock()
    return db


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
def teacher_user():
    teacher = Teacher(teacher_id=uuid.uuid4(), class_id=uuid.uuid4(), full_name="Cô Mai")
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
def client_teacher(mock_db, teacher_user):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_get_returns_health_fields(client, mock_db):
    child = Child(
        child_id=uuid.uuid4(),
        parent_id=PARENT_A,
        full_name="Bé A",
        allergy_status="present",
        medical_allergies="Đậu phộng",
        care_notes="Tránh nắng",
        health_version=3,
        health_update_source="parent",
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child

    resp = client.get(f"/api/children/{child.child_id}/health-profile")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["allergy_status"] == "present"
    assert body["medical_allergies"] == "Đậu phộng"
    assert body["care_notes"] == "Tránh nắng"
    assert body["health_version"] == 3


def test_patch_requires_allergy_text_when_present(client, mock_db, parent_user):
    child = Child(
        child_id=uuid.uuid4(),
        parent_id=parent_user.parent_id,
        full_name="Bé A",
        allergy_status="unknown",
        health_version=1,
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child

    resp = client.patch(
        f"/api/children/{child.child_id}/health-profile",
        json={
            "allergy_status": "present",
            "medical_allergies": " ",
            "expected_version": 1,
        },
    )
    assert resp.status_code == 422


def test_patch_stale_version_returns_409(client, mock_db, parent_user):
    child = Child(
        child_id=uuid.uuid4(),
        parent_id=parent_user.parent_id,
        full_name="Bé A",
        allergy_status="unknown",
        health_version=2,
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child
    mock_db.query.return_value.filter.return_value.update.return_value = 0

    resp = client.patch(
        f"/api/children/{child.child_id}/health-profile",
        json={"allergy_status": "none", "expected_version": 1},
    )
    assert resp.status_code == 409


def test_patch_success_writes_health_fields(client, mock_db, parent_user):
    child = Child(
        child_id=uuid.uuid4(),
        parent_id=parent_user.parent_id,
        full_name="Bé A",
        allergy_status="unknown",
        health_version=1,
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child
    mock_db.query.return_value.filter.return_value.update.return_value = 1

    resp = client.patch(
        f"/api/children/{child.child_id}/health-profile",
        json={
            "allergy_status": "present",
            "medical_allergies": " Đậu phộng ",
            "expected_version": 1,
        },
    )
    assert resp.status_code == 200, resp.text
    payload = mock_db.query.return_value.filter.return_value.update.call_args.args[0]
    assert payload["allergy_status"] == "present"
    assert payload["medical_allergies"] == "Đậu phộng"
    assert payload["health_update_source"] == "parent"
    assert payload["health_updated_by_user_id"] == parent_user.user_id


def test_teacher_cannot_patch(client_teacher, mock_db):
    resp = client_teacher.patch(
        f"/api/children/{uuid.uuid4()}/health-profile",
        json={"allergy_status": "none", "expected_version": 1},
    )
    assert resp.status_code == 403


def test_teacher_can_read_own_class_child(client_teacher, mock_db, teacher_user):
    child = Child(
        child_id=uuid.uuid4(),
        class_id=teacher_user.teacher.class_id,
        full_name="Bé A",
        allergy_status="none",
        health_version=1,
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child

    resp = client_teacher.get(f"/api/children/{child.child_id}/health-profile")
    assert resp.status_code == 200, resp.text


def test_get_other_parent_child_returns_403(client, mock_db, parent_user):
    child = Child(
        child_id=uuid.uuid4(),
        parent_id=uuid.uuid4(),
        full_name="Bé B",
        allergy_status="none",
        health_version=1,
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child

    resp = client.get(f"/api/children/{child.child_id}/health-profile")
    assert resp.status_code == 403


def test_patch_forbids_extra_fields(client, mock_db, parent_user):
    resp = client.patch(
        f"/api/children/{uuid.uuid4()}/health-profile",
        json={"health_version": 99, "expected_version": 1},
    )
    assert resp.status_code == 422


def test_requires_auth(mock_db):
    app.dependency_overrides[get_db] = lambda: mock_db
    resp = TestClient(app).get(f"/api/children/{uuid.uuid4()}/health-profile")
    assert resp.status_code == 401
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# API admin: /api/admin/children
# ---------------------------------------------------------------------------

app.include_router(admin_router, prefix="/api")


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


def test_admin_update_without_health_fields_keeps_parent_data(admin_client, mock_db):
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        allergy_status="present",
        medical_allergies="Đậu phộng",
        care_notes="Tránh nắng",
        health_version=4,
        health_update_source="parent",
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}", json={"full_name": "Bé A2"}
    )
    assert resp.status_code == 200, resp.text
    assert child.full_name == "Bé A2"
    assert child.medical_allergies == "Đậu phộng"
    assert child.care_notes == "Tránh nắng"
    assert child.health_version == 4


def test_admin_update_health_fields_bumps_version(admin_client, mock_db):
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        allergy_status="unknown",
        health_version=2,
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}",
        json={
            "allergy_status": "present",
            "medical_allergies": " Đậu phộng ",
            "care_notes": "Tránh nắng",
        },
    )
    assert resp.status_code == 200, resp.text
    assert child.allergy_status == "present"
    assert child.medical_allergies == "Đậu phộng"
    assert child.care_notes == "Tránh nắng"
    assert child.health_version == 3
    assert child.health_update_source == "admin"


def test_admin_update_none_clears_allergy_text(admin_client, mock_db):
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        allergy_status="present",
        medical_allergies="Đậu phộng",
        health_version=1,
    )
    mock_db.query.return_value.filter.return_value.first.return_value = child

    resp = admin_client.put(
        f"/api/admin/children/{child.child_id}", json={"allergy_status": "none"}
    )
    assert resp.status_code == 200, resp.text
    assert child.allergy_status == "none"
    assert child.medical_allergies is None


def test_admin_children_requires_admin(client_teacher):
    assert client_teacher.get("/api/admin/children").status_code == 403


def test_admin_list_children_exposes_health_fields(admin_client, mock_db):
    child = Child(
        child_id=uuid.uuid4(),
        full_name="Bé A",
        allergy_status="none",
        care_notes="Tránh nắng",
        health_version=2,
    )
    mock_db.query.return_value.all.return_value = [child]

    resp = admin_client.get("/api/admin/children")
    assert resp.status_code == 200, resp.text
    item = resp.json()[0]
    assert item["allergy_status"] == "none"
    assert item["care_notes"] == "Tránh nắng"
    assert item["health_version"] == 2
