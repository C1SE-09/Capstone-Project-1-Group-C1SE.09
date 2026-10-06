"""
tests/test_schedule.py
=======================
Integration & Unit tests cho Timetable APIs:
- TimeSlot CRUD
- Subject CRUD
- ClassSchedule CRUD (Option A - Flat Response) & Conflict checks
"""

import uuid
from unittest.mock import MagicMock

import pytest
from app.core.database import get_db
from app.core.security import get_current_user
from app.main import app
from app.models.user import User, UserRole
from fastapi.testclient import TestClient

CLASS_ID = uuid.UUID("aaaaaaaa-0000-0000-0000-000000000001")
TEACHER_ID = uuid.UUID("bbbbbbbb-0000-0000-0000-000000000001")
SLOT_ID = uuid.UUID("11111111-0000-0000-0000-000000000001")
SUBJECT_ID = uuid.UUID("22222222-0000-0000-0000-000000000001")
SCHEDULE_ID = uuid.UUID("33333333-0000-0000-0000-000000000001")


@pytest.fixture()
def mock_db():
    db = MagicMock()
    db.query = MagicMock()
    db.add = MagicMock()
    db.commit = MagicMock()
    db.delete = MagicMock()
    db.refresh = MagicMock()
    return db


@pytest.fixture()
def fake_user():
    user = MagicMock(spec=User)
    user.user_id = uuid.uuid4()
    user.role = UserRole.ADMIN
    return user


@pytest.fixture()
def client(mock_db, fake_user):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: fake_user

    yield TestClient(app)

    app.dependency_overrides.clear()


class TestTimeSlotAPI:
    def test_get_time_slots(self, client, mock_db):
        mock_slot = MagicMock()
        mock_slot.slot_id = SLOT_ID
        mock_slot.name = "07:00 - 07:30"
        mock_slot.start_time = "07:00"
        mock_slot.end_time = "07:30"
        mock_slot.order_index = 1

        mock_db.query.return_value.order_by.return_value.all.return_value = [mock_slot]

        resp = client.get("/api/time-slots")
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        assert body[0]["name"] == "07:00 - 07:30"

    def test_create_time_slot(self, client, mock_db):
        payload = {
            "name": "07:30 - 08:00",
            "start_time": "07:30",
            "end_time": "08:00",
            "order_index": 2,
        }
        resp = client.post("/api/time-slots", json=payload)
        assert resp.status_code == 201
        assert mock_db.add.called
        assert mock_db.commit.called


class TestSubjectAPI:
    def test_get_subjects(self, client, mock_db):
        mock_sub = MagicMock()
        mock_sub.subject_id = SUBJECT_ID
        mock_sub.name = "Thể dục"
        mock_sub.code = "PE"
        mock_sub.color_code = "#4CAF50"
        mock_sub.description = "Thể dục buổi sáng"

        mock_db.query.return_value.order_by.return_value.all.return_value = [mock_sub]

        resp = client.get("/api/subjects")
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        assert body[0]["name"] == "Thể dục"


class TestClassScheduleAPI:
    def test_get_class_schedule_flat_option_a(self, client, mock_db):
        mock_sched = MagicMock()
        mock_sched.schedule_id = SCHEDULE_ID
        mock_sched.class_id = CLASS_ID
        mock_sched.subject_id = SUBJECT_ID
        mock_sched.slot_id = SLOT_ID
        mock_sched.teacher_id = TEACHER_ID
        mock_sched.day_of_week = 2
        mock_sched.activity_name = "Tập thể dục"
        mock_sched.content = "Tập sân trường"
        mock_sched.room_name = "Sân trường"
        mock_sched.is_active = True

        mock_slot = MagicMock()
        mock_slot.slot_id = SLOT_ID
        mock_slot.name = "07:00 - 07:30"
        mock_slot.start_time = "07:00"
        mock_slot.end_time = "07:30"
        mock_slot.order_index = 1
        mock_sched.time_slot = mock_slot

        mock_sub = MagicMock()
        mock_sub.subject_id = SUBJECT_ID
        mock_sub.name = "Thể dục"
        mock_sub.code = "PE"
        mock_sub.color_code = "#4CAF50"
        mock_sub.description = None
        mock_sched.subject = mock_sub

        mock_teacher = MagicMock()
        mock_teacher.teacher_id = TEACHER_ID
        mock_teacher.full_name = "Cô Mai"
        mock_teacher.email = "mai@kinder.edu.vn"
        mock_sched.teacher = mock_teacher

        # mock SQLAlchemy query chain
        mock_db.query.return_value.options.return_value.filter.return_value.join.return_value.order_by.return_value.all.return_value = [
            mock_sched
        ]

        resp = client.get(f"/api/schedules/class/{CLASS_ID}")
        assert resp.status_code == 200
        body = resp.json()
        assert isinstance(body, list)
        assert len(body) == 1
        assert body[0]["schedule_id"] == str(SCHEDULE_ID)
        assert body[0]["day_of_week"] == 2
        assert body[0]["subject"]["name"] == "Thể dục"
        assert body[0]["time_slot"]["name"] == "07:00 - 07:30"
