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
from app.api.endpoints.admin import router as admin_router
from app.api.endpoints.schedule import router as schedule_router
from app.api.endpoints.schedule import subject_router, time_slot_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.schedule import ClassSchedule, Subject, TimeSlot
from app.models.user import Class_, User, UserRole
from app.services import schedule_service
from fastapi import FastAPI
from fastapi.testclient import TestClient

app = FastAPI()
app.include_router(schedule_router, prefix="/api")
app.include_router(time_slot_router, prefix="/api")
app.include_router(subject_router, prefix="/api")
app.include_router(admin_router, prefix="/api")

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

        mock_sched.custom_start_time = None
        mock_sched.custom_end_time = None

        # mock SQLAlchemy query chain
        mock_db.query.return_value.options.return_value.filter.return_value.outerjoin.return_value.order_by.return_value.all.return_value = [
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


class TestCustomScheduleTimesNoSlotCreation:
    """Verify free-form hours save onto class_schedule without inserting into time_slot."""

    def _make_standard_slots(self):
        s1 = TimeSlot(
            slot_id=uuid.UUID("e0000000-0000-0000-0000-000000000001"),
            name="7h00 - 7h30",
            start_time="07:00",
            end_time="07:30",
            order_index=1,
        )
        s2 = TimeSlot(
            slot_id=uuid.UUID("e0000000-0000-0000-0000-000000000002"),
            name="8h15 - 9h00",
            start_time="08:15",
            end_time="09:00",
            order_index=3,
        )
        return [s1, s2]

    def test_admin_create_custom_time_does_not_create_time_slot(self, client, mock_db):
        cls_obj = Class_(class_id=CLASS_ID, name="Lớp Mầm 1")
        subj_obj = Subject(subject_id=SUBJECT_ID, name="Hoạt động sáng")

        class _QueryStub:
            def __init__(self, result):
                self._result = result

            def filter(self, *args, **kwargs):
                return self

            def order_by(self, *args, **kwargs):
                return self

            def first(self):
                return self._result

        def query_side_effect(model):
            if model is Class_:
                return _QueryStub(cls_obj)
            if model is Subject:
                return _QueryStub(subj_obj)
            if model is TimeSlot:
                # No existing slot matches 07:15 - 07:45
                return _QueryStub(None)
            return _QueryStub(None)

        mock_db.query.side_effect = query_side_effect

        resp = client.post(
            "/api/admin/schedules",
            json={
                "activity_name": "Giờ tự do buổi sáng",
                "content": "Trò chơi nhẹ",
                "room_name": "Phòng 101",
                "slot_id": None,
                "start_time": "07:15",
                "end_time": "07:45",
                "class_id": str(CLASS_ID),
                "day_of_week": 2,
            },
        )
        assert resp.status_code == 201
        added_objects = [call.args[0] for call in mock_db.add.call_args_list]
        assert not any(isinstance(obj, TimeSlot) for obj in added_objects)
        sched_objs = [obj for obj in added_objects if isinstance(obj, ClassSchedule)]
        assert len(sched_objs) == 1
        created = sched_objs[0]
        assert created.slot_id is None
        assert created.custom_start_time == "07:15"
        assert created.custom_end_time == "07:45"

    def test_admin_create_matching_time_reuses_existing_slot(self, client, mock_db):
        s1, _ = self._make_standard_slots()
        cls_obj = Class_(class_id=CLASS_ID, name="Lớp Mầm 1")
        subj_obj = Subject(subject_id=SUBJECT_ID, name="Hoạt động sáng")

        class _QueryStub:
            def __init__(self, result):
                self._result = result

            def filter(self, *args, **kwargs):
                return self

            def order_by(self, *args, **kwargs):
                return self

            def first(self):
                return self._result

        def query_side_effect(model):
            if model is Class_:
                return _QueryStub(cls_obj)
            if model is Subject:
                return _QueryStub(subj_obj)
            if model is TimeSlot:
                return _QueryStub(s1)
            return _QueryStub(None)

        mock_db.query.side_effect = query_side_effect

        resp = client.post(
            "/api/admin/schedules",
            json={
                "activity_name": "Đón trẻ",
                "slot_id": None,
                "start_time": "7:00",
                "end_time": "7:30",
                "class_id": str(CLASS_ID),
                "day_of_week": 2,
            },
        )
        assert resp.status_code == 201
        added_objects = [call.args[0] for call in mock_db.add.call_args_list]
        assert not any(isinstance(obj, TimeSlot) for obj in added_objects)
        created = next(obj for obj in added_objects if isinstance(obj, ClassSchedule))
        assert created.slot_id == s1.slot_id
        assert created.custom_start_time is None
        assert created.custom_end_time is None

    @pytest.mark.parametrize(
        "start_time,end_time",
        [
            ("19:10", "20:40"),
            ("10:00", "09:00"),
            ("25:00", "26:00"),
            ("07:30", None),
        ],
    )
    def test_admin_create_rejects_invalid_or_out_of_hours(
        self, client, mock_db, start_time, end_time
    ):
        cls_obj = Class_(class_id=CLASS_ID, name="Lớp Mầm 1")
        subj_obj = Subject(subject_id=SUBJECT_ID, name="Hoạt động")

        class _QueryStub:
            def __init__(self, result):
                self._result = result

            def filter(self, *args, **kwargs):
                return self

            def order_by(self, *args, **kwargs):
                return self

            def first(self):
                return self._result

        def query_side_effect(model):
            if model is Class_:
                return _QueryStub(cls_obj)
            if model is Subject:
                return _QueryStub(subj_obj)
            return _QueryStub(None)

        mock_db.query.side_effect = query_side_effect

        resp = client.post(
            "/api/admin/schedules",
            json={
                "activity_name": "Ngoài giờ",
                "slot_id": None,
                "start_time": start_time,
                "end_time": end_time,
                "class_id": str(CLASS_ID),
                "day_of_week": 2,
            },
        )
        assert resp.status_code == 400
        mock_db.add.assert_not_called()

    def test_admin_update_switches_between_slot_and_custom_times(self, client, mock_db):
        s1, _ = self._make_standard_slots()
        sched = ClassSchedule(
            schedule_id=SCHEDULE_ID,
            class_id=CLASS_ID,
            subject_id=SUBJECT_ID,
            slot_id=s1.slot_id,
            day_of_week=2,
            activity_name="Cũ",
            is_active=True,
        )

        class _QueryStub:
            def __init__(self, result):
                self._result = result

            def filter(self, *args, **kwargs):
                return self

            def first(self):
                return self._result

        def query_side_effect(model):
            if model is ClassSchedule:
                return _QueryStub(sched)
            if model is TimeSlot:
                return _QueryStub(None)
            return _QueryStub(None)

        mock_db.query.side_effect = query_side_effect

        resp = client.put(
            f"/api/admin/schedules/{SCHEDULE_ID}",
            json={
                "activity_name": "Giờ tự do mới",
                "slot_id": None,
                "start_time": "08:25",
                "end_time": "08:55",
            },
        )
        assert resp.status_code == 200
        assert sched.slot_id is None
        assert sched.custom_start_time == "08:25"
        assert sched.custom_end_time == "08:55"
        assert not any(
            isinstance(call.args[0], TimeSlot) for call in mock_db.add.call_args_list
        )

        # Now switch back to existing standard slot
        def query_side_effect_back(model):
            if model is ClassSchedule:
                return _QueryStub(sched)
            if model is TimeSlot:
                return _QueryStub(s1)
            return _QueryStub(None)

        mock_db.query.side_effect = query_side_effect_back
        resp_back = client.put(
            f"/api/admin/schedules/{SCHEDULE_ID}",
            json={
                "slot_id": str(s1.slot_id),
                "start_time": None,
                "end_time": None,
            },
        )
        assert resp_back.status_code == 200
        assert sched.slot_id == s1.slot_id
        assert sched.custom_start_time is None
        assert sched.custom_end_time is None

    def test_list_and_class_schedule_sort_custom_entries_chronologically(
        self, client, mock_db
    ):
        s1, s2 = self._make_standard_slots()
        cls_obj = Class_(class_id=CLASS_ID, name="Lớp Mầm 1")
        subj_obj = Subject(subject_id=SUBJECT_ID, name="Vẽ", color_code="#4CAF50")
        custom_id = uuid.uuid4()

        sched_late = ClassSchedule(
            schedule_id=uuid.uuid4(),
            class_id=CLASS_ID,
            subject_id=SUBJECT_ID,
            slot_id=s2.slot_id,
            day_of_week=2,
            activity_name="Tiết 08:15",
            is_active=True,
            time_slot=s2,
            subject=subj_obj,
            class_=cls_obj,
        )
        sched_early = ClassSchedule(
            schedule_id=uuid.uuid4(),
            class_id=CLASS_ID,
            subject_id=SUBJECT_ID,
            slot_id=s1.slot_id,
            day_of_week=2,
            activity_name="Tiết 07:00",
            is_active=True,
            time_slot=s1,
            subject=subj_obj,
            class_=cls_obj,
        )
        sched_custom = ClassSchedule(
            schedule_id=custom_id,
            class_id=CLASS_ID,
            subject_id=SUBJECT_ID,
            slot_id=None,
            custom_start_time="07:45",
            custom_end_time="08:10",
            day_of_week=2,
            activity_name="Giờ tự do giữa",
            is_active=True,
            time_slot=None,
            subject=subj_obj,
            class_=cls_obj,
        )

        # Admin endpoint list_schedules
        mock_db.query.return_value.join.return_value.filter.return_value.all.return_value = [
            sched_late,
            sched_custom,
            sched_early,
        ]
        resp_admin = client.get(f"/api/admin/schedules?class_id={CLASS_ID}")
        assert resp_admin.status_code == 200
        admin_rows = resp_admin.json()
        assert [r["start_time"] for r in admin_rows] == ["07:00", "07:45", "08:15"]
        assert admin_rows[1]["slot_id"] is None
        assert admin_rows[1]["time_range"] == "07:45 - 08:10"

        # Mobile endpoint /api/schedules/class/{id} synthesizes virtual time_slot
        mock_db.query.return_value.options.return_value.filter.return_value.outerjoin.return_value.order_by.return_value.all.return_value = [
            sched_late,
            sched_custom,
            sched_early,
        ]
        resp_mobile = client.get(f"/api/schedules/class/{CLASS_ID}")
        assert resp_mobile.status_code == 200
        mobile_rows = resp_mobile.json()
        assert [r["activity_name"] for r in mobile_rows] == [
            "Tiết 07:00",
            "Giờ tự do giữa",
            "Tiết 08:15",
        ]
        assert mobile_rows[1]["slot_id"] is None
        assert mobile_rows[1]["custom_start_time"] == "07:45"
        assert mobile_rows[1]["custom_end_time"] == "08:10"
        assert mobile_rows[1]["time_slot"]["name"] == "07:45 - 08:10"
        assert mobile_rows[1]["time_slot"]["slot_id"] == str(custom_id)

    def test_service_update_preserves_custom_time_when_mobile_sends_synthetic_slot_id(
        self, mock_db
    ):
        from app.schemas.schedule import ClassScheduleUpdate

        sched = ClassSchedule(
            schedule_id=SCHEDULE_ID,
            class_id=CLASS_ID,
            subject_id=SUBJECT_ID,
            slot_id=None,
            custom_start_time="07:45",
            custom_end_time="08:10",
            day_of_week=2,
            activity_name="Cũ",
            is_active=True,
        )

        class _QueryStub:
            def __init__(self, result):
                self._result = result

            def options(self, *args, **kwargs):
                return self

            def filter(self, *args, **kwargs):
                return self

            def first(self):
                return self._result

        mock_db.query.return_value = _QueryStub(sched)
        updated = schedule_service.update_class_schedule(
            mock_db,
            SCHEDULE_ID,
            ClassScheduleUpdate(
                slot_id=SCHEDULE_ID,
                activity_name="Tên mới",
            ),
        )
        assert updated is sched
        assert sched.activity_name == "Tên mới"
        assert sched.slot_id is None
        assert sched.custom_start_time == "07:45"
        assert sched.custom_end_time == "08:10"
