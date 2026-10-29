"""Hồi quy hợp đồng, phân quyền và nghiệp vụ đơn nghỉ/báo trễ."""

import io
import uuid
from datetime import date, datetime, time, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from minio.error import S3Error
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.endpoints import leave_requests as routes
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import (
    AttendanceRecord,
    AttendanceStatus,
    Base,
    Child,
    ChildStatus,
    Class_,
    LeaveRequest,
    LeaveRequestStatus,
    LeaveType,
    Parent,
    ParentChild,
    School,
    Teacher,
    User,
    UserRole,
)
from app.schemas.leave_request_schema import ParentLeaveRequestCreate as LeaveRequestCreate

TODAY = date(2030, 1, 5)
VN = timezone(timedelta(hours=7))
WARNING = "Đơn gửi sau 7:30 vẫn có thể tính tiền ăn bán trú hôm nay. Bạn có đồng ý không"


@pytest.fixture()
def env(monkeypatch):
    engine = create_engine(
        "sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    tables = [
        Base.metadata.tables[name]
        for name in (
            "school", "class", "teacher", "parent", "child", "parent_child",
            "users", "leave_request", "attendance_record",
        )
    ]
    Base.metadata.create_all(engine, tables=tables)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    db = factory()
    school = School(school_id=uuid.uuid4(), name="Trường A", code="A")
    class_ = Class_(class_id=uuid.uuid4(), school=school, name="Lớp A")
    other_class = Class_(class_id=uuid.uuid4(), school=school, name="Lớp B")
    parents = [
        Parent(parent_id=uuid.uuid4(), full_name=name, phone=f"090000000{i}")
        for i, name in enumerate(("Mẹ An", "Bố An", "Mẹ Bình"))
    ]
    child = Child(
        child_id=uuid.uuid4(), full_name="Bé An", parent=parents[0], class_=class_
    )
    other_child = Child(
        child_id=uuid.uuid4(), full_name="Bé Bình", parent=parents[2], class_=other_class
    )
    db.add_all([school, class_, other_class, *parents, child, other_child])
    db.flush()
    db.add(ParentChild(child_id=child.child_id, parent_id=parents[1].parent_id))
    teacher = Teacher(
        teacher_id=uuid.uuid4(), full_name="Cô Mai", school=school, class_=class_,
        email="mai@example.test",
    )
    users = [
        User(user_id=uuid.uuid4(), username=f"parent{i}", password_hash="x",
             role=UserRole.PARENT, parent_id=parent.parent_id)
        for i, parent in enumerate(parents)
    ]
    teacher_user = User(
        user_id=uuid.uuid4(), username="teacher", password_hash="x",
        role=UserRole.TEACHER, teacher=teacher,
    )
    admin = User(
        user_id=uuid.uuid4(), username="admin", password_hash="x", role=UserRole.ADMIN
    )
    db.add_all([*users, teacher_user, admin])
    db.commit()
    state = SimpleNamespace(
        db=db, factory=factory, child=child, other_child=other_child,
        class_=class_, other_class=other_class, parents=users,
        teacher=teacher_user, admin=admin, actor=users[0],
        now=datetime(2030, 1, 5, 7, 30, tzinfo=VN), statements=[],
    )

    class Clock(datetime):
        @classmethod
        def now(cls, tz=None):
            return state.now.astimezone(tz) if tz else state.now.replace(tzinfo=None)

    from app.services import leave_request_service
    from app.services import attendance_sync_service
    import app.config as app_config

    monkeypatch.setattr(leave_request_service, "datetime", Clock)
    monkeypatch.setattr(attendance_sync_service, "datetime", Clock)
    monkeypatch.setattr(app_config, "datetime", Clock)

    def record_sql(orm_state):
        state.statements.append(orm_state.statement)

    event.listen(Session, "do_orm_execute", record_sql)
    app = FastAPI()
    app.include_router(routes.router, prefix="/api")

    def request_db():
        with factory() as session:
            yield session

    app.dependency_overrides[get_db] = request_db
    app.dependency_overrides[get_current_user] = lambda: state.actor
    state.app = app
    with TestClient(app, raise_server_exceptions=False) as client:
        state.client = client
        yield state
    event.remove(Session, "do_orm_execute", record_sql)
    db.close()
    engine.dispose()


def payload(env, **changes):
    return {
        "child_id": str(env.child.child_id), "class_id": str(env.class_.class_id),
        "from_date": "2030-01-05", "to_date": "2030-01-05",
        "reason": "  Bé cần nghỉ  ", **changes,
    }


def create(env, **changes):
    return env.client.post("/api/leave-requests", json=payload(env, **changes))


def seed_request(env, **changes):
    old_kind = changes.pop("request_type", None)
    if old_kind is not None:
        changes["type"] = LeaveType.LATE if old_kind == "late_arrival" else LeaveType.SINGLE_DAY
    if changes.get("reviewed_by") == env.teacher.teacher_id:
        changes["reviewed_by"] = env.teacher.user_id
    values = {
        "request_id": uuid.uuid4(), "child_id": env.child.child_id,
        "parent_id": env.parents[0].parent_id, "class_id": env.class_.class_id,
        "from_date": TODAY, "to_date": TODAY, "reason": "Bé cần nghỉ",
        "status": LeaveRequestStatus.PENDING, **changes,
    }
    req = LeaveRequest(**values)
    env.db.add(req)
    env.db.commit()
    return req


def count_requests(env):
    with env.factory() as db:
        return db.scalar(select(func.count()).select_from(LeaveRequest))


def test_serializer_uses_profile_full_names(env):
    req = seed_request(env, reviewed_by=env.teacher.teacher_id)
    dto = routes._to_response_dto(req).model_dump(mode="json")
    assert dto["parent_name"] == "Mẹ An"
    assert dto["reviewer_name"] == "Cô Mai"
    assert dto["request_type"] == "absence"
    assert dto["expected_arrival_time"] is None
    assert dto["meal_warning_acknowledged"] is False


@pytest.mark.parametrize("hour,minute,state,allowed", [
    (7, 29, LeaveRequestStatus.PENDING, True), (7, 30, LeaveRequestStatus.PENDING, False),
    (7, 29, LeaveRequestStatus.APPROVED, True), (7, 29, LeaveRequestStatus.REJECTED, False),
    (7, 29, LeaveRequestStatus.CANCELLED, False),
])
def test_cancel_metadata_uses_server_cutoff_and_status(env, hour, minute, state, allowed):
    env.now = datetime(2030, 1, 5, hour, minute, tzinfo=VN)
    req = seed_request(env, status=state)
    response = env.client.get(f"/api/leave-requests/{req.request_id}")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["can_cancel"] is allowed
    assert datetime.fromisoformat(body["cancel_before"]) == datetime(2030, 1, 5, 7, 30, tzinfo=VN)
    assert (body["cancel_block_reason"] is None) is allowed


def test_future_request_can_cancel_after_today_cutoff_but_readonly_family_member_cannot(env):
    env.now = datetime(2030, 1, 5, 15, 0, tzinfo=VN)
    req = seed_request(env, from_date=TODAY + timedelta(days=1), to_date=TODAY + timedelta(days=1))
    assert env.client.get(f"/api/leave-requests/{req.request_id}").json()["can_cancel"] is True
    env.actor = env.parents[1]
    body = env.client.get(f"/api/leave-requests/{req.request_id}").json()
    assert body["can_cancel"] is False
    assert body["cancel_block_reason"]
    assert env.client.post(f"/api/leave-requests/{req.request_id}/cancel").status_code == 403


def test_cancellation_eligibility_normalizes_utc_to_vietnam_cutoff(env):
    from app.services.attendance_sync_service import cancellation_eligibility
    req = seed_request(env)
    assert cancellation_eligibility(req, datetime(2030, 1, 5, 0, 29, tzinfo=timezone.utc))[0] is True
    assert cancellation_eligibility(req, datetime(2030, 1, 5, 0, 30, tzinfo=timezone.utc))[0] is False


@pytest.mark.parametrize("parent_index", [0, 1])
def test_parent_create_supports_legacy_and_many_to_many_links(env, parent_index):
    env.actor = env.parents[parent_index]
    response = create(env)
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["reason"] == "Bé cần nghỉ"
    assert body["parent_id"] == str(env.actor.parent_id)
    assert body["class_id"] == str(env.child.class_id)
    assert body["request_type"] == "absence"
    assert body["status"] == "pending"


def test_class_can_be_derived_when_omitted(env):
    data = payload(env)
    del data["class_id"]
    response = env.client.post("/api/leave-requests", json=data)
    assert response.status_code == 201, response.text
    assert response.json()["class_id"] == str(env.child.class_id)


@pytest.mark.parametrize("kind", ["absence", "late_arrival"])
def test_parent_submission_endpoint_preserves_request_type(env, kind):
    data = payload(env, request_type=kind)
    if kind == "late_arrival":
        data["expected_arrival_time"] = "09:00:00"
    response = env.client.post("/api/leave-requests/parent", json=data)
    assert response.status_code == 201, response.text
    assert response.json()["request_type"] == kind
    assert response.json()["status"] == "pending"


@pytest.mark.parametrize("changes,expected", [
    ({"reason": " a "}, 422),
    ({"reason": " " * 5}, 422),
    ({"reason": "a" * 1001}, 422),
    ({"from_date": "2030-01-06"}, 422),
    ({"from_date": "2030-02-30"}, 422),
    ({"from_date": 0}, 422),
    ({"from_date": "2030-01-04"}, 422),
    ({"to_date": "2031-01-06"}, 422),
    ({"request_type": "unknown"}, 422),
    ({"request_type": "late_arrival"}, 422),
    ({"request_type": "late_arrival", "to_date": "2030-01-06",
      "expected_arrival_time": "09:00:00"}, 422),
    ({"expected_arrival_time": "09:00:00"}, 422),
    ({"request_type": "late_arrival", "expected_arrival_time": "07:29:59"}, 422),
    ({"request_type": "late_arrival", "expected_arrival_time": "07:30:00"}, 422),
    ({"request_type": "late_arrival", "expected_arrival_time": "25:00:00"}, 422),
    ({"request_type": "late_arrival", "expected_arrival_time": "09:00:00Z"}, 422),
    ({"request_type": "late_arrival", "expected_arrival_time": 36000}, 422),
])
def test_create_rejects_invalid_reason_dates_and_eta_without_insert(env, changes, expected):
    response = create(env, **changes)
    assert response.status_code == expected, response.text
    assert count_requests(env) == 0


def test_reason_limits_apply_after_trimming(env):
    data = LeaveRequestCreate.model_validate(payload(env, reason=" " + "a" * 1000 + " "))
    assert data.reason == "a" * 1000
    with pytest.raises(ValidationError):
        LeaveRequestCreate.model_validate(payload(env, reason=" a "))


def test_create_accepts_exactly_366_days(env):
    response = create(env, to_date="2031-01-05")
    assert response.status_code == 201, response.text


def test_late_arrival_is_pending_and_does_not_create_attendance(env):
    response = create(env, request_type="late_arrival", expected_arrival_time="09:15:00")
    assert response.status_code == 201, response.text
    assert response.json()["request_type"] == "late_arrival"
    assert response.json()["expected_arrival_time"] == "09:15:00"
    with env.factory() as db:
        assert db.scalar(select(func.count()).select_from(AttendanceRecord)) == 0


@pytest.mark.parametrize("kind", ["absence", "late_arrival"])
def test_after_cutoff_requires_acknowledgement_before_insert(env, kind):
    env.now = datetime(2030, 1, 5, 7, 30, 0, 1, tzinfo=VN)
    changes = {"request_type": kind}
    if kind == "late_arrival":
        changes["expected_arrival_time"] = "09:00:00"
    response = create(env, **changes)
    assert response.status_code == 409, response.text
    assert response.json()["detail"] == {"code": "meal_warning_required", "message": WARNING}
    assert count_requests(env) == 0
    accepted = create(env, meal_warning_acknowledged=True, **changes)
    assert accepted.status_code == 201, accepted.text
    assert accepted.json()["meal_warning_acknowledged"] is True
    with env.factory() as db:
        assert db.scalar(select(LeaveRequest)).meal_warning_acknowledged is True


def test_future_only_requests_do_not_warn_after_cutoff(env):
    env.now = datetime(2030, 1, 5, 23, 59, tzinfo=VN)
    response = create(env, from_date="2030-01-06", to_date="2030-01-06",
                      request_type="late_arrival", expected_arrival_time="00:01:00")
    assert response.status_code == 201, response.text


def test_cutoff_uses_server_time_after_waiting_for_child_lock(env):
    env.now = datetime(2030, 1, 5, 7, 29, tzinfo=VN)

    def advance_clock(orm_state):
        text = str(orm_state.statement.compile(dialect=postgresql.dialect()))
        if "FOR UPDATE OF child" in text:
            env.now = datetime(2030, 1, 5, 7, 31, tzinfo=VN)

    event.listen(Session, "do_orm_execute", advance_clock)
    try:
        response = create(env)
    finally:
        event.remove(Session, "do_orm_execute", advance_clock)
    assert response.status_code == 409, response.text
    assert response.json()["detail"]["code"] == "meal_warning_required"
    assert count_requests(env) == 0


def test_date_and_cutoff_follow_vietnam_not_utc(env):
    env.now = datetime(2030, 1, 5, 18, 0, tzinfo=timezone.utc)
    assert create(env).status_code == 422
    response = create(env, from_date="2030-01-06", to_date="2030-01-06")
    assert response.status_code == 201, response.text


def test_create_for_another_child_is_forbidden(env):
    response = create(env, child_id=str(env.other_child.child_id),
                      class_id=str(env.other_class.class_id))
    assert response.status_code == 403, response.text
    assert count_requests(env) == 0


def test_class_spoofing_is_rejected(env):
    assert create(env, class_id=str(env.other_class.class_id)).status_code == 422
    assert count_requests(env) == 0


@pytest.mark.parametrize("actor", ["teacher", "admin"])
def test_staff_cannot_impersonate_a_parent_to_create(env, actor):
    env.actor = getattr(env, actor)
    assert create(env).status_code == 403
    assert count_requests(env) == 0


@pytest.mark.parametrize("status", [LeaveRequestStatus.PENDING, LeaveRequestStatus.APPROVED])
@pytest.mark.parametrize("parent_index", [0, 1])
def test_inclusive_overlap_blocks_both_linked_parents(env, status, parent_index):
    seed_request(env, from_date=TODAY + timedelta(days=1), to_date=TODAY + timedelta(days=3),
                 status=status)
    env.actor = env.parents[parent_index]
    response = create(env, from_date="2030-01-08", to_date="2030-01-09")
    assert response.status_code == 409, response.text
    assert response.json()["detail"]["code"] == "overlapping_request"
    assert count_requests(env) == 1


def test_rejected_request_does_not_block_a_new_request(env):
    seed_request(env, status=LeaveRequestStatus.REJECTED)
    response = create(env)
    assert response.status_code == 201, response.text
    assert count_requests(env) == 2


def test_adjacent_non_overlapping_request_is_allowed(env):
    seed_request(env)
    response = create(env, from_date="2030-01-06", to_date="2030-01-06")
    assert response.status_code == 201, response.text


@pytest.mark.parametrize("existing_type,new_type", [
    ("absence", "late_arrival"), ("late_arrival", "absence"), ("late_arrival", "late_arrival"),
])
def test_overlap_applies_across_both_request_types(env, existing_type, new_type):
    seed_request(env, request_type=existing_type,
                 expected_arrival_time=time(9, 0) if existing_type == "late_arrival" else None)
    response = create(env, request_type=new_type,
                      expected_arrival_time="09:00:00" if new_type == "late_arrival" else None)
    assert response.status_code == 409, response.text
    assert response.json()["detail"]["code"] == "overlapping_request"


def test_other_child_request_does_not_block_create(env):
    seed_request(env, child_id=env.other_child.child_id,
                 class_id=env.other_class.class_id, parent_id=env.parents[2].parent_id)
    response = create(env)
    assert response.status_code == 201, response.text


def test_create_locks_only_child_before_checking_overlap(env):
    response = create(env)
    assert response.status_code == 201, response.text
    sql = [str(statement.compile(dialect=postgresql.dialect())) for statement in env.statements]
    lock_index = next((i for i, text in enumerate(sql) if "FOR UPDATE OF child" in text), None)
    overlap_index = next((i for i, text in enumerate(sql) if "leave_request.from_date <=" in text), None)
    assert lock_index is not None, "Thiếu khóa DB theo bé"
    assert overlap_index is not None and lock_index < overlap_index
    assert not any(text.rstrip().endswith("FOR UPDATE") for text in sql)


def test_mine_is_child_scoped_paginated_and_sorted(env):
    old = seed_request(env, status=LeaveRequestStatus.REJECTED,
                       created_at=datetime(2029, 12, 1, tzinfo=timezone.utc))
    new = seed_request(env, parent_id=env.parents[1].parent_id,
                       created_at=datetime(2029, 12, 2, tzinfo=timezone.utc))
    seed_request(env, child_id=env.other_child.child_id, class_id=env.other_class.class_id,
                 parent_id=env.parents[2].parent_id)
    response = env.client.get("/api/leave-requests/mine", params={
        "child_id": str(env.child.child_id), "offset": 0, "limit": 1,
    })
    assert response.status_code == 200, response.text
    body = response.json()
    assert (body["total"], body["offset"], body["limit"]) == (2, 0, 1)
    assert [item["request_id"] for item in body["items"]] == [str(new.request_id)]
    response = env.client.get("/api/leave-requests/mine", params={
        "child_id": str(env.child.child_id), "status": "rejected",
    })
    assert response.json()["total"] == 1
    assert response.json()["items"][0]["request_id"] == str(old.request_id)


@pytest.mark.parametrize("query", [
    {"status": "reviewed"}, {"offset": -1}, {"limit": 0}, {"limit": 101},
    {"child_id": "../bad"},
])
def test_mine_validates_filters(env, query):
    response = env.client.get("/api/leave-requests/mine", params={
        "child_id": str(env.child.child_id), **query,
    })
    assert response.status_code == 422, response.text


def test_mine_forbids_unlinked_child_and_nonparent(env):
    url = "/api/leave-requests/mine"
    assert env.client.get(url, params={"child_id": str(env.other_child.child_id)}).status_code == 403
    env.actor = env.teacher
    assert env.client.get(url, params={"child_id": str(env.child.child_id)}).status_code == 403


def test_detail_allows_both_linked_parents_class_teacher_and_admin(env):
    req = seed_request(env)
    for actor in [*env.parents[:2], env.teacher, env.admin]:
        env.actor = actor
        response = env.client.get(f"/api/leave-requests/{req.request_id}")
        assert response.status_code == 200, response.text
        assert response.json()["request_id"] == str(req.request_id)
    env.actor = env.parents[2]
    assert env.client.get(f"/api/leave-requests/{req.request_id}").status_code == 403


def test_detail_missing_or_invalid_uuid(env):
    assert env.client.get(f"/api/leave-requests/{uuid.uuid4()}").status_code == 404
    assert env.client.get("/api/leave-requests/not-a-uuid").status_code == 422


def test_routes_require_authentication(env):
    env.app.dependency_overrides.pop(get_current_user)
    for method, path, kwargs in [
        ("get", f"/api/leave-requests/mine?child_id={env.child.child_id}", {}),
        ("get", f"/api/leave-requests/{uuid.uuid4()}", {}),
        ("post", "/api/leave-requests", {"json": payload(env)}),
    ]:
        assert getattr(env.client, method)(path, **kwargs).status_code == 401


@pytest.mark.parametrize("action", ["approve", "reject"])
def test_review_locks_only_request_and_refuses_a_second_transition(env, action):
    req = seed_request(env)
    env.actor = env.teacher
    kwargs = {"json": {"reject_reason": "Không phù hợp"}} if action == "reject" else {}
    url = f"/api/leave-requests/{req.request_id}/{action}"
    first = env.client.post(url, **kwargs)
    assert first.status_code == 200, first.text
    assert first.json()["reviewer_name"] == "Cô Mai"
    second = env.client.post(url, **kwargs)
    assert second.status_code == 400
    locks = [str(s.compile(dialect=postgresql.dialect())) for s in env.statements
             if getattr(s, "_for_update_arg", None) is not None]
    assert locks and all("FOR UPDATE OF leave_request" in text for text in locks)


def test_review_refreshes_cached_pending_state_before_transition(env):
    req = seed_request(env)
    with env.factory() as other_session:
        persisted = other_session.get(LeaveRequest, req.request_id)
        persisted.status = LeaveRequestStatus.REJECTED
        other_session.commit()
    assert req.status == LeaveRequestStatus.PENDING
    env.app.dependency_overrides[get_db] = lambda: env.db
    env.actor = env.teacher
    response = env.client.post(f"/api/leave-requests/{req.request_id}/approve")
    assert response.status_code == 400, response.text
    assert req.status == LeaveRequestStatus.REJECTED


@pytest.mark.parametrize("action", ["approve", "reject"])
def test_review_rejects_parent_or_other_class_teacher(env, action):
    req = seed_request(env, child_id=env.other_child.child_id,
                       class_id=env.other_class.class_id, parent_id=env.parents[2].parent_id)
    kwargs = {"json": {"reject_reason": "Không phù hợp"}} if action == "reject" else {}
    for actor in [env.parents[2], env.teacher]:
        env.actor = actor
        assert env.client.post(f"/api/leave-requests/{req.request_id}/{action}", **kwargs).status_code == 403
    env.db.refresh(req)
    assert req.status == LeaveRequestStatus.PENDING


def test_absence_approval_preserves_present_late_and_real_checkin(env):
    req = seed_request(env, to_date=TODAY + timedelta(days=4))
    for i, (status, checkin) in enumerate([
        (AttendanceStatus.PRESENT, None), (AttendanceStatus.LATE, time(9, 0)),
        (AttendanceStatus.ABSENT, time(8, 0)), (AttendanceStatus.ABSENT, None),
    ]):
        env.db.add(AttendanceRecord(
            child_id=env.child.child_id, class_id=env.class_.class_id,
            date=TODAY + timedelta(days=i), status=status, check_in_time=checkin,
            note=f"Ghi nhận {i}",
        ))
    env.db.commit()
    env.actor = env.teacher
    response = env.client.post(f"/api/leave-requests/{req.request_id}/approve")
    assert response.status_code == 200, response.text
    with env.factory() as db:
        records = db.scalars(select(AttendanceRecord).order_by(AttendanceRecord.date)).all()
        assert len(records) == 5
        assert [r.status for r in records] == [AttendanceStatus.PRESENT, AttendanceStatus.LATE,
                                               AttendanceStatus.ABSENT, AttendanceStatus.ABSENT,
                                               AttendanceStatus.EXCUSED_ABSENT]
        assert [r.note for r in records[:4]] == ["Ghi nhận 0", "Ghi nhận 1", "Ghi nhận 2", "Ghi nhận 3"]
        assert records[2].check_in_time == time(8, 0)
        assert records[4].note == "Nghỉ có phép"
        assert all(row.source_leave_id is None for row in records[:4])
        assert records[4].source_leave_id == req.request_id
    upserts = [s.compile(dialect=postgresql.dialect())
               for s in env.statements if getattr(s, "is_insert", False)]
    assert upserts and all("ON CONFLICT (child_id, date) DO NOTHING" in str(sql) for sql in upserts)


def test_approval_refuses_oversized_legacy_date_range(env):
    req = seed_request(env, to_date=TODAY + timedelta(days=366))
    env.actor = env.teacher
    response = env.client.post(f"/api/leave-requests/{req.request_id}/approve")
    assert response.status_code == 422, response.text
    env.db.refresh(req)
    assert req.status == LeaveRequestStatus.PENDING
    with env.factory() as db:
        assert db.scalar(select(func.count()).select_from(AttendanceRecord)) == 0


def test_late_approval_syncs_late_attendance_with_eta_and_no_actual_checkin(env):
    response = create(env, request_type="late_arrival", expected_arrival_time="09:00:00")
    assert response.status_code == 201, response.text
    env.actor = env.teacher
    approved = env.client.post(f"/api/leave-requests/{response.json()['request_id']}/approve")
    assert approved.status_code == 200, approved.text
    assert approved.json()["synced_attendance_count"] == 1
    with env.factory() as db:
        record = db.scalar(select(AttendanceRecord))
        assert record is not None
        assert record.status == AttendanceStatus.LATE
        assert record.expected_arrival_time == time(9, 0)
        assert record.check_in_time is None
        assert record.source_leave_id == uuid.UUID(response.json()["request_id"])


def test_teacher_list_and_parent_history_carry_type_eta_and_decision(env):
    response = create(env, request_type="late_arrival", expected_arrival_time="09:00:00")
    assert response.status_code == 201, response.text
    request_id = response.json()["request_id"]
    env.actor = env.teacher
    class_url = f"/api/leave-requests/class/{env.class_.class_id}"
    pending = env.client.get(class_url).json()
    assert pending["pending_count"] == 1
    assert pending["items"][0]["request_type"] == "late_arrival"
    assert pending["items"][0]["expected_arrival_time"] == "09:00:00"
    assert env.client.post(f"/api/leave-requests/{request_id}/approve").status_code == 200
    reviewed = env.client.get(class_url, params={"tab": "reviewed"}).json()
    assert (reviewed["pending_count"], reviewed["reviewed_count"]) == (0, 1)
    assert reviewed["items"][0]["status"] == "approved"
    env.actor = env.parents[1]
    history = env.client.get("/api/leave-requests/mine", params={
        "child_id": str(env.child.child_id), "status": "approved",
    }).json()
    assert history["total"] == 1
    assert history["items"][0]["reviewer_name"] == "Cô Mai"
    assert history["items"][0]["expected_arrival_time"] == "09:00:00"


def test_review_does_not_log_medical_or_rejection_reason(env, caplog):
    req = seed_request(env, reason="Thông tin y tế riêng tư")
    env.actor = env.teacher
    with caplog.at_level("INFO"):
        response = env.client.post(f"/api/leave-requests/{req.request_id}/reject",
                                   json={"reject_reason": "Lý do riêng tư"})
    assert response.status_code == 200, response.text
    assert "Lý do riêng tư" not in caplog.text
    assert "Thông tin y tế riêng tư" not in caplog.text


PNG = b"\x89PNG\r\n\x1a\n" + b"image-test"
JPEG = b"\xff\xd8\xff\xe0" + b"image-test\xff\xd9"
WEBP = b"RIFF\x10\x00\x00\x00WEBPVP8 " + b"image-test"
MAX_IMAGE = 5 * 1024 * 1024


class ImageStream(io.BytesIO):
    released = False

    def read(self, size=-1):
        assert 0 < size <= MAX_IMAGE + 1, "Phải giới hạn bytes tải từ storage"
        return super().read(size)

    def release_conn(self):
        self.released = True


class MemoryMinio:
    """Chỉ thay SDK bên ngoài; route, phân quyền và validation vẫn chạy thật."""

    def __init__(self):
        self.objects = {}
        self.public = True
        self.buckets = set()
        self.failure = False
        self.streams = []

    def check(self, bucket_name):
        assert bucket_name.endswith("-leave-requests")
        if self.failure:
            raise RuntimeError("private-storage-credentials-must-not-leak")

    def bucket_exists(self, bucket_name):
        self.check(bucket_name)
        return bucket_name in self.buckets

    def make_bucket(self, bucket_name):
        self.check(bucket_name)
        self.buckets.add(bucket_name)

    def delete_bucket_policy(self, bucket_name):
        self.check(bucket_name)
        self.public = False

    def put_object(self, bucket_name, object_name, data, length, content_type, metadata):
        self.check(bucket_name)
        assert not self.public, "Không được lưu ảnh y tế trong bucket public"
        child_id, attachment_id = object_name.split("/")
        assert str(uuid.UUID(child_id)) == child_id
        assert str(uuid.UUID(attachment_id)) == attachment_id
        contents = data.read()
        assert len(contents) == length <= MAX_IMAGE
        self.objects[object_name] = {
            "data": contents, "content_type": content_type,
            "metadata": {f"x-amz-meta-{k.lower()}": v for k, v in metadata.items()},
        }

    def stat_object(self, bucket_name, object_name):
        self.check(bucket_name)
        if object_name not in self.objects:
            raise S3Error("NoSuchKey", "missing", object_name, None, None, None)
        obj = self.objects[object_name]
        return SimpleNamespace(size=len(obj["data"]), content_type=obj["content_type"],
                               metadata=obj["metadata"])

    def get_object(self, bucket_name, object_name):
        self.check(bucket_name)
        stream = ImageStream(self.objects[object_name]["data"])
        self.streams.append(stream)
        return stream


@pytest.fixture()
def image_storage(monkeypatch):
    from app.core import storage

    fake = MemoryMinio()
    monkeypatch.setattr(storage, "minio_client", fake)
    return fake


def upload(env, data=PNG, mime="image/png", child_id=None):
    return env.client.post("/api/leave-requests/attachments",
                           params={"child_id": str(child_id or env.child.child_id)},
                           files={"file": ("../../private-name.png", data, mime)})


@pytest.mark.parametrize("data,mime", [(PNG, "image/png"), (JPEG, "image/jpeg"), (WEBP, "image/webp")])
def test_private_attachment_round_trip_and_safe_headers(env, image_storage, data, mime):
    response = upload(env, data, mime)
    assert response.status_code == 201, response.text
    path = response.json()["attachment_url"]
    prefix = f"/api/leave-requests/attachments/{env.child.child_id}/"
    assert path.startswith(prefix)
    uuid.UUID(path.removeprefix(prefix))
    assert "private-name" not in path
    assert not image_storage.public
    response = env.client.get(path)
    assert response.status_code == 200, response.text
    assert response.content == data
    assert response.headers["content-type"] == mime
    assert response.headers["cache-control"] == "private, no-store"
    assert response.headers["x-content-type-options"] == "nosniff"
    assert all(stream.closed and stream.released for stream in image_storage.streams)
    created = create(env, attachment_url=path)
    assert created.status_code == 201, created.text
    assert created.json()["attachment_url"] == path


@pytest.mark.parametrize("data,mime", [
    (b"<svg>unsafe</svg>", "image/svg+xml"),
    (b"<script>unsafe</script>", "image/png"),
    (PNG, "image/jpeg"), (b"", "image/png"), (b"RIFF", "image/webp"),
    (PNG + b"x" * MAX_IMAGE, "image/png"),
], ids=["svg", "fake-png", "wrong-mime", "empty", "bad-webp", "oversize"])
def test_attachment_rejects_mime_spoofing_and_oversize_before_storage(env, image_storage, data, mime):
    response = upload(env, data, mime)
    assert response.status_code == 422, response.text
    assert image_storage.objects == {}


def test_attachment_accepts_exactly_5_mib(env, image_storage):
    response = upload(env, PNG + b"x" * (MAX_IMAGE - len(PNG)))
    assert response.status_code == 201, response.text
    downloaded = env.client.get(response.json()["attachment_url"])
    assert downloaded.status_code == 200
    assert len(downloaded.content) == MAX_IMAGE


def test_attachment_requires_parent_ownership_for_upload(env, image_storage):
    assert upload(env, child_id=env.other_child.child_id).status_code == 403
    env.actor = env.teacher
    assert upload(env).status_code == 403
    env.actor = env.parents[1]
    assert upload(env).status_code == 201


def test_attachment_read_allows_only_child_parents_teacher_and_admin(env, image_storage):
    response = upload(env)
    assert response.status_code == 201, response.text
    path = response.json()["attachment_url"]
    for actor in [*env.parents[:2], env.teacher, env.admin]:
        env.actor = actor
        assert env.client.get(path).status_code == 200
    env.actor = env.parents[2]
    assert env.client.get(path).status_code == 403
    env.actor = env.teacher
    env.teacher.teacher.class_id = env.other_class.class_id
    assert env.client.get(path).status_code == 403


@pytest.mark.parametrize("reference", [
    "https://example.test/medical.png", "http://127.0.0.1/private", "file:///private",
    "/api/leave-requests/attachments/../bad", "//evil.test/private",
    "/api/leave-requests/attachments/not-a-uuid/not-a-uuid",
])
def test_create_never_accepts_external_or_traversal_attachment_references(env, image_storage, reference):
    response = create(env, attachment_url=reference)
    assert response.status_code == 422, response.text
    assert count_requests(env) == 0


def test_attachment_reference_is_bound_to_child_and_authenticated_uploader(env, image_storage):
    response = upload(env)
    assert response.status_code == 201, response.text
    path = response.json()["attachment_url"]
    env.actor = env.parents[1]
    assert create(env, attachment_url=path).status_code == 403
    env.actor = env.parents[0]
    wrong_child = path.replace(str(env.child.child_id), str(env.other_child.child_id))
    assert create(env, attachment_url=wrong_child).status_code == 422
    key = path.removeprefix("/api/leave-requests/attachments/")
    image_storage.objects[key]["metadata"]["x-amz-meta-child-id"] = str(env.other_child.child_id)
    assert create(env, attachment_url=path).status_code == 403
    assert env.client.get(path).status_code == 404
    assert count_requests(env) == 0


def test_attachment_missing_uuid_and_query_suffix_are_rejected(env, image_storage):
    prefix = f"/api/leave-requests/attachments/{env.child.child_id}"
    assert env.client.get(f"{prefix}/{uuid.uuid4()}").status_code == 404
    assert env.client.get(f"{prefix}/not-a-uuid").status_code == 422
    assert upload(env, child_id="not-a-uuid").status_code == 422
    response = upload(env)
    assert response.status_code == 201, response.text
    path = response.json()["attachment_url"]
    assert create(env, attachment_url=path + "?other=1").status_code == 422


def test_attachment_storage_failures_are_503_without_sensitive_logs(env, image_storage, caplog):
    response = upload(env)
    assert response.status_code == 201, response.text
    path = response.json()["attachment_url"]
    image_storage.failure = True
    with caplog.at_level("WARNING"):
        for response in [upload(env), env.client.get(path), create(env, attachment_url=path)]:
            assert response.status_code == 503, response.text
            assert "private-storage-credentials" not in response.text
    assert "private-storage-credentials" not in caplog.text
    assert count_requests(env) == 0


def test_corrupt_stored_attachment_is_not_served_as_image(env, image_storage):
    response = upload(env)
    assert response.status_code == 201, response.text
    path = response.json()["attachment_url"]
    key = path.removeprefix("/api/leave-requests/attachments/")
    image_storage.objects[key]["data"] = b"<script>corrupt</script>"
    response = env.client.get(path)
    assert response.status_code == 503, response.text
    assert b"<script>" not in response.content
    assert all(stream.closed and stream.released for stream in image_storage.streams)


def test_attachment_routes_require_authentication(env, image_storage):
    env.app.dependency_overrides.pop(get_current_user)
    assert upload(env).status_code == 401
    assert env.client.get(
        f"/api/leave-requests/attachments/{env.child.child_id}/{uuid.uuid4()}"
    ).status_code == 401


def test_orm_uses_existing_database_column_names():
    sql = str(select(LeaveRequest).compile(dialect=postgresql.dialect()))
    assert "leave_request.request_id" in sql
    assert "leave_request.reviewed_at" in sql
    assert "leave_request.leave_id" not in sql
    assert "leave_request.action_at" not in sql


def test_batch_api_and_parent_gateway_share_one_history(env):
    first = env.client.post("/api/leave-requests", json={
        "children": [{"child_id": str(env.child.child_id), "type": "late",
                      "from_date": "2030-01-06", "expected_arrival_time": "09:00:00"}],
        "reason": "Bé đi khám buổi sáng",
    })
    assert first.status_code == 201, first.text
    item = first.json()["requests"][0]
    assert item["type"] == "late" and item["request_type"] == "late_arrival"
    duplicate = env.client.post("/api/leave-requests/parent", json=payload(
        env, from_date="2030-01-06", to_date="2030-01-06",
    ))
    assert duplicate.status_code == 409, duplicate.text
    assert count_requests(env) == 1
    history = env.client.get(f"/api/leave-requests/student/{env.child.child_id}")
    assert history.status_code == 200, history.text
    assert history.json()["data"][0]["leave_id"] == item["leave_id"]


def test_batch_failure_is_atomic_for_unlinked_second_child(env):
    response = env.client.post("/api/leave-requests", json={
        "children": [
            {"child_id": str(env.child.child_id), "type": "single_day", "from_date": "2030-01-06"},
            {"child_id": str(env.other_child.child_id), "type": "single_day", "from_date": "2030-01-06"},
        ], "reason": "Gia đình có việc riêng",
    })
    assert response.status_code == 403, response.text
    assert count_requests(env) == 0


def test_cancel_only_rolls_back_generated_excused_rows_and_preserves_actual_records(env):
    env.client._transport.raise_server_exceptions = True
    env.now = datetime(2030, 1, 5, 7, 0, tzinfo=VN)
    req = seed_request(env, to_date=TODAY + timedelta(days=2), type=LeaveType.MULTI_DAY)
    for i, kind in [(0, AttendanceStatus.PRESENT), (2, AttendanceStatus.EXCUSED_ABSENT)]:
        env.db.add(AttendanceRecord(child_id=env.child.child_id, class_id=env.class_.class_id,
            date=TODAY + timedelta(days=i), status=kind, note=f"Giáo viên ghi nhận {i}"))
    env.db.commit()
    env.actor = env.teacher
    response = env.client.post(f"/api/leave-requests/{req.request_id}/approve")
    assert response.status_code == 200, response.text
    with env.factory() as db:
        generated = db.scalar(select(AttendanceRecord).where(AttendanceRecord.date == TODAY + timedelta(days=1)))
        assert generated.status == AttendanceStatus.EXCUSED_ABSENT
        assert generated.source_leave_id == req.request_id
    env.actor = env.parents[0]
    response = env.client.post(f"/api/leave-requests/{req.request_id}/cancel")
    assert response.status_code == 200, response.text
    assert response.json()["status"] == "cancelled"
    with env.factory() as db:
        records = db.scalars(select(AttendanceRecord).order_by(AttendanceRecord.date)).all()
        assert [row.status for row in records] == [AttendanceStatus.PRESENT, AttendanceStatus.EXCUSED_ABSENT]
        assert [row.note for row in records] == ["Giáo viên ghi nhận 0", "Giáo viên ghi nhận 2"]


@pytest.mark.parametrize("child_status", [ChildStatus.WITHDRAWN, ChildStatus.GRADUATED])
@pytest.mark.parametrize("endpoint", ["", "/parent"])
def test_inactive_child_cannot_receive_new_requests(env, child_status, endpoint):
    env.child.status = child_status
    env.db.commit()
    data = payload(env) if endpoint else {
        "children": [{"child_id": str(env.child.child_id), "type": "single_day", "from_date": "2030-01-05"}],
        "reason": "Xin nghỉ một ngày",
    }
    response = env.client.post(f"/api/leave-requests{endpoint}", json=data)
    assert response.status_code == 404, response.text
    assert count_requests(env) == 0


def test_batch_default_date_remains_today_in_vietnam(env):
    env.now = datetime(2030, 1, 5, 18, 0, tzinfo=timezone.utc)
    response = env.client.post("/api/leave-requests", json={
        "children": [{"child_id": str(env.child.child_id), "type": "single_day"}],
        "reason": "Ngày mặc định theo giờ Việt Nam",
    })
    assert response.status_code == 201, response.text
    assert response.json()["requests"][0]["from_date"] == "2030-01-06"


def test_shared_batch_image_stays_private_for_each_child_and_class(env, image_storage):
    env.db.add(ParentChild(child_id=env.other_child.child_id, parent_id=env.parents[0].parent_id))
    teacher = Teacher(teacher_id=uuid.uuid4(), full_name="Cô lớp B", school_id=env.other_class.school_id,
                      class_id=env.other_class.class_id, email="teacher-b@example.test")
    teacher_user = User(user_id=uuid.uuid4(), username="teacher-b", password_hash="x", role=UserRole.TEACHER,
                        teacher=teacher)
    env.db.add_all([teacher, teacher_user])
    env.db.commit()
    source = upload(env).json()["attachment_url"]
    response = env.client.post("/api/leave-requests", json={
        "children": [{"child_id": str(child.child_id), "type": "single_day", "from_date": "2030-01-06"}
                     for child in [env.child, env.other_child]],
        "reason": "Gia đình gửi chung giấy khám", "attachment_url": source,
    })
    assert response.status_code == 201, response.text
    paths = [item["attachment_url"] for item in response.json()["requests"]]
    assert paths[0] == source and paths[1] != source
    assert paths[1].startswith(f"/api/leave-requests/attachments/{env.other_child.child_id}/")
    env.actor = env.teacher
    assert env.client.get(paths[0]).status_code == 200
    assert env.client.get(paths[1]).status_code == 403
    env.actor = teacher_user
    assert env.client.get(paths[0]).status_code == 403
    assert env.client.get(paths[1]).content == PNG


@pytest.mark.parametrize("change", ["withdrawn", "class"])
def test_approval_refuses_stale_child_profile_without_changing_attendance(env, change):
    req = seed_request(env)
    if change == "withdrawn":
        env.child.status = ChildStatus.WITHDRAWN
    else:
        env.child.class_id = env.other_class.class_id
    env.db.commit()
    env.actor = env.teacher
    response = env.client.post(f"/api/leave-requests/{req.request_id}/approve")
    assert response.status_code == 409, response.text
    with env.factory() as db:
        assert db.get(LeaveRequest, req.request_id).status == LeaveRequestStatus.PENDING
        assert db.scalar(select(func.count()).select_from(AttendanceRecord)) == 0


def test_cancel_requires_parent_still_linked_to_child(env):
    env.now = datetime(2030, 1, 5, 7, 0, tzinfo=VN)
    req = seed_request(env)
    env.child.parent_id = env.parents[2].parent_id
    env.db.commit()
    response = env.client.post(f"/api/leave-requests/{req.request_id}/cancel")
    assert response.status_code == 403, response.text
    env.db.refresh(req)
    assert req.status == LeaveRequestStatus.PENDING
