"""Hồi quy HTTP/DB thật: quyền theo bé/lớp và một nguồn trạng thái cho cữ thuốc."""

import uuid
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from sqlalchemy import func, select

from app.api.endpoints import medication as routes
from app.models.child import Child, ChildStatus, Parent, ParentChild
from app.models.medication import MedicationLog, MedicationRequest, MedicationRequestStatus as State
from app.models.user import Class_, Teacher, User, UserRole
from test_medication import db_session as db_session, engine as engine, seed_data as seed_data, get_test_client


@pytest.fixture()
def env(db_session, seed_data, monkeypatch):
    sent = []
    monkeypatch.setattr(routes.send_medication_confirmed_notification, "delay", lambda *args: sent.append(args))
    class_b = Class_(school_id=seed_data["class"].school_id, name="Lớp khác")
    parent_b = Parent(full_name="Phụ huynh khác", phone="0987654321")
    db_session.add_all([class_b, parent_b])
    db_session.flush()
    teacher_b = Teacher(school_id=seed_data["class"].school_id, class_id=class_b.class_id,
                        full_name="Cô lớp khác", email="other-teacher@example.test")
    child_b = Child(class_id=class_b.class_id, parent=parent_b, full_name="Bé lớp khác",
                    status=ChildStatus.ENROLLED)
    db_session.add_all([teacher_b, child_b])
    db_session.flush()
    user_teacher_b = User(username="other-teacher", password_hash="x", role=UserRole.TEACHER,
                          teacher_id=teacher_b.teacher_id)
    user_parent_b = User(username="other-parent", password_hash="x", role=UserRole.PARENT,
                         parent_id=parent_b.parent_id)
    db_session.add_all([user_teacher_b, user_parent_b])
    db_session.commit()
    return SimpleNamespace(db=db_session, seed=seed_data, sent=sent, class_b=class_b,
                           child_b=child_b, teacher_b=user_teacher_b, parent_b=user_parent_b,
                           client=lambda user: get_test_client(db_session, user))


def dose(env, **changes):
    values = dict(request_id=uuid.uuid4(), batch_id=uuid.uuid4(),
                  child_id=env.seed["child"].child_id, parent_id=env.seed["parent"].parent_id,
                  class_id=env.seed["class"].class_id, medication_name="Thuốc theo hướng dẫn",
                  dosage="5ml", start_date=date.today(), end_date=date.today(),
                  request_date=date.today(), time_slot="08:30", status=State.PENDING,
                  created_by_user_id=env.seed["user_parent"].user_id, created_by_role="parent")
    values.update(changes)
    req = MedicationRequest(**values)
    env.db.add(req)
    env.db.commit()
    return req


def confirm(client, req, route):
    if route == "canonical":
        return client.post(f"/api/medication-requests/{req.request_id}/confirm")
    if route == "legacy-post":
        return client.post("/api/teacher/medications/confirm", params={"date": str(req.request_date)},
                           json={"request_id": str(req.request_id), "session": "morning"})
    return client.put(f"/api/teacher/medications/{req.request_id}/confirm",
                      params={"date": str(req.request_date)}, json={"session": "morning"})


@pytest.mark.parametrize("first_route,second_route", [
    ("canonical", "legacy-put"), ("legacy-put", "canonical"),
    ("canonical", "legacy-post"), ("legacy-post", "canonical"),
])
def test_confirmation_endpoints_share_one_dose_and_one_notification(env, first_route, second_route):
    req = dose(env)
    first = confirm(env.client(env.seed["user_teacher_mai"]), req, first_route)
    second = confirm(env.client(env.seed["user_teacher_hoa"]), req, second_route)
    assert (first.status_code, second.status_code) == (200, 409), (first.text, second.text)
    env.db.refresh(req)
    assert req.status == State.GIVEN
    assert req.given_by_id == env.seed["teacher_mai"].teacher_id
    logs = env.db.scalars(select(MedicationLog)).all()
    assert len(logs) == 1 and logs[0].is_given
    assert logs[0].given_by_id == req.given_by_id
    assert len(env.sent) == 1


def test_new_slots_and_legacy_schedule_appear_once_in_teacher_today(env):
    for time in ["08:30", "09:30", "11:30"]:
        dose(env, time_slot=time)
    legacy = dose(env, batch_id=None, request_date=None, time_slot=None, status=State.ACTIVE,
                  sessions=["morning", "noon"])
    response = env.client(env.seed["user_teacher_mai"]).get(
        "/api/teacher/medications/today", params={"date": str(date.today())})
    assert response.status_code == 200, response.text
    data = response.json()
    assert [len(data[key]) for key in ["morning", "noon", "afternoon"]] == [3, 2, 0]
    assert {item["time_slot"] for item in data["morning"] if item["request_id"] != str(legacy.request_id)} == {"08:30", "09:30"}
    assert data["completed_count"] == 0 and data["pending_count"] == 5


@pytest.mark.parametrize("operation", ["detail", "list-child", "list-class", "create", "confirm", "cancel"])
def test_other_class_cannot_read_or_mutate_medication(env, operation):
    req = dose(env)
    client = env.client(env.teacher_b)
    if operation == "detail":
        response = client.get(f"/api/medication-requests/{req.request_id}")
    elif operation == "list-child":
        response = client.get("/api/medication-requests", params={"child_id": str(req.child_id)})
    elif operation == "list-class":
        response = client.get("/api/medication-requests", params={"class_id": str(req.class_id)})
    elif operation == "confirm":
        response = confirm(client, req, "canonical")
    elif operation == "create":
        response = client.post("/api/medication-requests", json={
            "child_id": str(req.child_id), "from_date": str(date.today()), "time_slots": ["09:30"],
            "dosage": "5ml", "prescription_image_url": "https://example.test/prescription.png",
        })
    else:
        response = client.post(f"/api/medication-requests/{req.request_id}/cancel")
    assert response.status_code == 403, response.text
    env.db.refresh(req)
    assert req.status == State.PENDING
    assert env.db.scalar(select(func.count()).select_from(MedicationLog)) == 0
    assert env.sent == []


def test_teacher_without_profile_cannot_list_all_medication(env):
    dose(env)
    user = User(username="unassigned", password_hash="x", role=UserRole.TEACHER)
    env.db.add(user)
    env.db.commit()
    response = env.client(user).get("/api/medication-requests")
    assert response.status_code == 403, response.text


def test_unlinked_parent_cannot_read_or_cancel_another_childs_dose(env):
    req = dose(env)
    client = env.client(env.parent_b)
    assert client.get(f"/api/medication-requests/{req.request_id}").status_code == 403
    assert client.get("/api/medication-requests", params={"child_id": str(req.child_id)}).status_code == 403
    assert client.post(f"/api/medication-requests/{req.request_id}/cancel").status_code == 403
    env.db.refresh(req)
    assert req.status == State.PENDING


def test_linked_parent_reads_family_history_but_cannot_confirm(env):
    req = dose(env)
    env.db.add(ParentChild(parent_id=env.parent_b.parent_id, child_id=req.child_id))
    env.db.commit()
    client = env.client(env.parent_b)
    response = client.get("/api/medication-requests", params={"child_id": str(req.child_id)})
    assert response.status_code == 200, response.text
    assert [row["id"] for row in response.json()] == [str(req.request_id)]
    assert confirm(client, req, "canonical").status_code == 403
    assert confirm(client, req, "legacy-put").status_code == 403


def test_batch_cancellation_checks_every_child_before_any_write(env):
    first = dose(env)
    second = dose(env, batch_id=first.batch_id, child_id=env.child_b.child_id,
                  class_id=env.class_b.class_id, parent_id=env.parent_b.parent_id)
    response = env.client(env.seed["user_parent"]).post(f"/api/medication-requests/batch/{first.batch_id}/cancel")
    assert response.status_code == 403, response.text
    env.db.refresh(first)
    env.db.refresh(second)
    assert first.status == second.status == State.PENDING


@pytest.mark.parametrize("change", ["withdrawn", "moved"])
def test_confirmation_rejects_stale_child_profile_without_audit(env, change):
    req = dose(env)
    if change == "withdrawn":
        env.seed["child"].status = ChildStatus.WITHDRAWN
    else:
        env.seed["child"].class_id = env.class_b.class_id
    env.db.commit()
    response = confirm(env.client(env.seed["user_teacher_mai"]), req, "canonical")
    assert response.status_code == 409, response.text
    env.db.refresh(req)
    assert req.status == State.PENDING
    assert env.db.scalar(select(func.count()).select_from(MedicationLog)) == 0


@pytest.mark.parametrize("state", [State.CANCELLED, State.COMPLETED])
def test_legacy_confirmation_cannot_reactivate_inactive_medication(env, state):
    req = dose(env, request_date=None, time_slot=None, status=state, sessions=["morning"])
    response = env.client(env.seed["user_teacher_mai"]).put(
        f"/api/teacher/medications/{req.request_id}/confirm", params={"date": str(date.today())},
        json={"session": "morning"})
    assert response.status_code == 400, response.text
    assert env.db.scalar(select(func.count()).select_from(MedicationLog)) == 0


def test_legacy_confirmation_cannot_write_unrequested_date_or_session(env):
    req = dose(env, request_date=None, time_slot=None, status=State.ACTIVE, sessions=["morning"])
    client = env.client(env.seed["user_teacher_mai"])
    for day, session in [(date.today() + timedelta(days=1), "morning"), (date.today(), "noon")]:
        response = client.put(f"/api/teacher/medications/{req.request_id}/confirm",
                              params={"date": str(day)}, json={"session": session})
        assert response.status_code == 400, response.text
    assert env.db.scalar(select(func.count()).select_from(MedicationLog)) == 0


def test_legacy_dto_does_not_fabricate_exact_time_or_creator(env):
    req = dose(env, batch_id=None, request_date=None, time_slot=None, status=State.ACTIVE,
               created_by_user_id=None, created_by_role=None, sessions=["morning", "noon"])
    response = env.client(env.seed["user_parent"]).get(f"/api/medication-requests/{req.request_id}")
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["request_date"] is None and data["time_slot"] is None
    assert data["created_by_user_id"] is None and data["created_by_role"] is None
    assert data["sessions"] == ["morning", "noon"]


def test_legacy_missing_category_is_not_fabricated_as_prescription(env):
    req = dose(env, request_date=None, time_slot=None, status=State.ACTIVE, sessions=["morning"])
    req.medicine_category = None
    env.db.commit()
    response = env.client(env.seed["user_parent"]).get(f"/api/medication-requests/{req.request_id}")
    assert response.status_code == 200, response.text
    assert response.json()["medicine_category"] is None


def test_existing_legacy_log_for_new_slot_is_respected_without_read_side_effects(env):
    req = dose(env)
    env.db.add(MedicationLog(request_id=req.request_id, log_date=req.request_date,
                             session="morning", is_given=True,
                             given_by_id=env.seed["teacher_mai"].teacher_id,
                             given_at=datetime.now(timezone.utc)))
    env.db.commit()
    client = env.client(env.seed["user_parent"])
    response = client.get(f"/api/medication-requests/{req.request_id}")
    assert response.status_code == 200, response.text
    assert response.json()["status"] == "given"
    assert response.json()["given_by_id"] == str(env.seed["teacher_mai"].teacher_id)
    assert client.post(f"/api/medication-requests/{req.request_id}/cancel").status_code == 400
    env.db.refresh(req)
    assert req.status == State.PENDING
    assert env.sent == []


@pytest.mark.parametrize("slot,expected", [("10:59", "morning"), ("11:00", "noon"),
                                          ("13:59", "noon"), ("14:00", "afternoon")])
def test_session_bucket_boundaries(slot, expected):
    from app.services.medication_service import medication_session
    assert medication_session(slot) == expected
