"""Ảnh thuốc private và batch dùng HTTP/DB thật, chỉ thay MinIO SDK."""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import func, select

from app.config import get_today
from app.core import storage
from app.models.medication import MedicationLog, MedicationRequest
from medication_image_storage import PrescriptionMinio
from test_leave_requests import JPEG, MAX_IMAGE, PNG, WEBP
from test_medication import db_session as db_session, engine as engine, seed_data as seed_data
from test_medication_workflow import dose, env as env


@pytest.fixture()
def images(monkeypatch):
    fake = PrescriptionMinio()
    monkeypatch.setattr(storage, "minio_client", fake)
    return fake


def upload(env, data=PNG, mime="image/png", user=None, child_id=None):
    return env.client(user or env.seed["user_parent"]).post("/api/medication-requests/attachments",
        params={"child_id": str(child_id or env.seed["child"].child_id)},
        files={"file": ("../../private-prescription.png", data, mime)})


def payload(env, path, **changes):
    body = dict(child_id=str(env.seed["child"].child_id), from_date=str(get_today()),
                time_slots=["08:30", "11:30"], medicine_name="Thuốc theo chỉ định",
                dosage=" 5ml ", prescription_image_url=path)
    body.update(changes)
    return body


@pytest.mark.parametrize("data,mime", [(PNG, "image/png"), (JPEG, "image/jpeg"), (WEBP, "image/webp")])
def test_prescription_private_round_trip_is_bound_to_child_and_actor(env, images, data, mime):
    response = upload(env, data, mime)
    assert response.status_code == 201, response.text
    path = response.json()["prescription_image_url"]
    assert path.startswith(f"/api/medication-requests/attachments/{env.seed['child'].child_id}/")
    client = env.client(env.seed["user_parent"])
    image = client.get(path)
    assert image.content == data
    assert image.headers["content-type"] == mime
    assert image.headers["cache-control"] == "private, no-store"
    assert image.headers["x-content-type-options"] == "nosniff"
    assert not images.public and all(stream.closed and stream.released for stream in images.streams)
    assert env.client(env.parent_b).get(path).status_code == 403
    assert env.client(env.teacher_b).get(path).status_code == 403
    dose(env, prescription_image_url=path)
    assert env.client(env.seed["user_teacher_mai"]).get(path).status_code == 200


@pytest.mark.parametrize("data,mime", [(b"fake", "image/png"), (PNG, "image/jpeg"),
                                      (PNG + b"x" * MAX_IMAGE, "image/png"), (PNG, "text/html")],
                         ids=["not-image", "wrong-signature", "over-limit", "wrong-mime"])
def test_invalid_prescriptions_are_rejected_before_storage(env, images, data, mime):
    assert upload(env, data, mime).status_code == 422
    assert images.objects == {}


def test_foreign_child_cannot_be_uploaded_or_used_in_prescription(env, images):
    assert upload(env, child_id=env.child_b.child_id).status_code == 403
    path = upload(env).json()["prescription_image_url"]
    other_parent = env.client(env.parent_b)
    response = other_parent.post("/api/medication-requests", json=payload(env, path))
    assert response.status_code == 403
    assert env.db.scalar(select(func.count()).select_from(MedicationRequest)) == 0


@pytest.mark.parametrize("path", ["https://evil.example/prescription.png", "http://127.0.0.1:9000/private",
    "/api/leave-requests/attachments/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222"])
def test_creation_rejects_arbitrary_or_wrong_namespace_image_urls(env, images, path):
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests", json=payload(env, path))
    assert response.status_code == 422, response.text
    assert env.db.scalar(select(func.count()).select_from(MedicationRequest)) == 0


def test_photo_uploader_must_match_even_for_another_linked_parent(env, images):
    from app.models.child import ParentChild
    env.db.add(ParentChild(parent_id=env.parent_b.parent_id, child_id=env.seed["child"].child_id))
    env.db.commit()
    path = upload(env).json()["prescription_image_url"]
    response = env.client(env.parent_b).post("/api/medication-requests", json=payload(env, path))
    assert response.status_code == 403, response.text


@pytest.mark.parametrize("days,expected", [(1, 2), (7, 14), (8, 0)])
def test_inclusive_day_limit_and_slot_count(env, images, days, expected):
    path = upload(env).json()["prescription_image_url"]
    body = payload(env, path, to_date=str(get_today() + timedelta(days=days - 1)))
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests", json=body)
    assert response.status_code == (201 if expected else 422), response.text
    assert env.db.scalar(select(func.count()).select_from(MedicationRequest)) == expected
    if expected:
        assert response.json()["total_slots"] == expected
        assert all(item["dosage"] == "5ml" for item in response.json()["items"])


@pytest.mark.parametrize("changes", [{"dosage": "   "}, {"dosage": "x" * 256}, {"time_slots": ["25:30"]},
    {"time_slots": [f"{hour:02d}:00" for hour in range(24)] + ["00:30"]},
    {"from_date": "2020-01-01"}])
def test_invalid_batch_is_rejected_without_any_insert(env, images, changes):
    path = upload(env).json()["prescription_image_url"]
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests", json=payload(env, path, **changes))
    assert response.status_code == 422, response.text
    assert env.db.scalar(select(func.count()).select_from(MedicationRequest)) == 0


@pytest.mark.parametrize("category", ["prescription", "non_prescription", "supplement", "fever_reducer"])
def test_prescription_categories_and_full_dosage_round_trip(env, images, category):
    path = upload(env).json()["prescription_image_url"]
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests",
        json=payload(env, path, medicine_category=category, dosage="x" * 255))
    assert response.status_code == 201, response.text
    assert all(row["medicine_category"] == category and row["dosage"] == "x" * 255 for row in response.json()["items"])


def test_overlap_on_last_day_does_not_insert_earlier_slots(env, images):
    existing = dose(env, request_date=get_today() + timedelta(days=2), time_slot="11:30")
    path = upload(env).json()["prescription_image_url"]
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests",
        json=payload(env, path, to_date=str(get_today() + timedelta(days=2))))
    assert response.status_code == 409, response.text
    assert env.db.scalar(select(func.count()).select_from(MedicationRequest)) == 1
    assert env.db.get(MedicationRequest, existing.request_id) is not None


def test_cancelled_row_with_real_given_log_still_blocks_duplicate_dose(env, images):
    from app.models.medication import MedicationRequestStatus
    existing = dose(env, status=MedicationRequestStatus.CANCELLED)
    env.db.add(MedicationLog(request_id=existing.request_id, log_date=existing.request_date,
                             session="morning", is_given=True, given_at=datetime.now(timezone.utc),
                             given_by_id=env.seed["teacher_mai"].teacher_id))
    env.db.commit()
    path = upload(env).json()["prescription_image_url"]
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests", json=payload(env, path))
    assert response.status_code == 409, response.text
    assert env.db.scalar(select(func.count()).select_from(MedicationRequest)) == 1


def test_storage_failure_is_503_without_credential_leak(env, images, caplog):
    images.failure = True
    response = upload(env)
    assert response.status_code == 503, response.text
    assert "private-prescription-credentials" not in response.text + caplog.text


def test_batch_filter_and_pagination_keep_existing_list_envelope(env):
    first = dose(env)
    second = dose(env, batch_id=first.batch_id, time_slot="11:30")
    dose(env, time_slot="14:30")
    client = env.client(env.seed["user_parent"])
    query = {"child_id": str(first.child_id), "batch_id": str(first.batch_id), "offset": 0, "limit": 1}
    page1 = client.get("/api/medication-requests", params=query)
    page2 = client.get("/api/medication-requests", params={**query, "offset": 1})
    assert page1.status_code == page2.status_code == 200
    assert len(page1.json()) == len(page2.json()) == 1
    assert {page1.json()[0]["id"], page2.json()[0]["id"]} == {str(first.request_id), str(second.request_id)}


def test_default_request_day_is_vietnam_date_at_utc_boundary(env, images, monkeypatch):
    import app.config as config

    class Clock:
        @staticmethod
        def now(tz):
            return datetime(2030, 1, 5, 18, 0, tzinfo=timezone.utc).astimezone(tz)

    monkeypatch.setattr(config, "datetime", Clock)
    path = upload(env).json()["prescription_image_url"]
    body = payload(env, path)
    body.pop("from_date")
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests", json=body)
    assert response.status_code == 201, response.text
    assert {item["request_date"] for item in response.json()["items"]} == {"2030-01-06"}


def test_parent_teacher_complete_two_dose_lifecycle_with_real_audit(env, images):
    parent = env.client(env.seed["user_parent"])
    path = upload(env).json()["prescription_image_url"]
    created = parent.post("/api/medication-requests", json=payload(env, path))
    assert created.status_code == 201, created.text
    first, second = sorted(created.json()["items"], key=lambda row: row["time_slot"])
    teacher = env.client(env.seed["user_teacher_mai"])
    params = {"date": str(get_today())}
    schedule = teacher.get("/api/teacher/medications/today", params=params).json()
    assert schedule["pending_count"] == 2
    result = teacher.put(f"/api/teacher/medications/{first['id']}/confirm", params=params,
                         json={"session": "morning"})
    assert result.status_code == 200, result.text
    history = env.client(env.seed["user_parent"]).get("/api/medication-requests",
        params={"child_id": str(env.seed["child"].child_id), "batch_id": created.json()["batch_id"]}).json()
    given = next(row for row in history if row["id"] == first["id"])
    assert given["status"] == "given" and given["given_at"]
    assert given["given_by_id"] == str(env.seed["teacher_mai"].teacher_id)
    assert given["given_by_name"] == env.seed["teacher_mai"].full_name
    cancelled = env.client(env.seed["user_parent"]).post(f"/api/medication-requests/{second['id']}/cancel")
    assert cancelled.status_code == 200 and cancelled.json()["status"] == "cancelled"
    schedule = env.client(env.seed["user_teacher_mai"]).get("/api/teacher/medications/today", params=params).json()
    assert schedule["pending_count"] == 0 and schedule["completed_count"] == 1
    assert [row["request_id"] for row in schedule["morning"]] == [first["id"]]
    assert not schedule["noon"] and len(env.sent) == 1


def test_teacher_cannot_bypass_historical_request_class_via_prescription_path(env, images):
    path = upload(env).json()["prescription_image_url"]
    req = dose(env, prescription_image_url=path)
    env.seed["child"].class_id = env.class_b.class_id
    env.db.commit()
    teacher = env.client(env.teacher_b)
    assert teacher.get(f"/api/medication-requests/{req.request_id}").status_code == 403
    assert teacher.get(path).status_code == 403
    assert env.client(env.seed["user_parent"]).get(path).status_code == 200


def test_unreferenced_prescription_preview_is_uploader_only_for_teachers(env, images):
    path = upload(env, user=env.seed["user_teacher_mai"]).json()["prescription_image_url"]
    assert env.client(env.seed["user_teacher_mai"]).get(path).status_code == 200
    assert env.client(env.seed["user_teacher_hoa"]).get(path).status_code == 403
    dose(env, prescription_image_url=path)
    assert env.client(env.seed["user_teacher_hoa"]).get(path).status_code == 200


def test_changed_class_rejects_stale_parent_form_without_creating_any_doses(env, images):
    path = upload(env).json()["prescription_image_url"]
    snapshot = str(env.seed["child"].class_id)
    env.seed["child"].class_id = env.class_b.class_id
    env.db.commit()
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests",
        json=payload(env, path, expected_class_id=snapshot))
    assert response.status_code == 409, response.text
    assert env.db.scalar(select(func.count()).select_from(MedicationRequest)) == 0
    response = env.client(env.seed["user_parent"]).post("/api/medication-requests",
        json=payload(env, path, expected_class_id=str(env.class_b.class_id)))
    assert response.status_code == 201, response.text
    assert {row["class_id"] for row in response.json()["items"]} == {str(env.class_b.class_id)}
