"""Chạy riêng trên PostgreSQL test_db; không dùng DB thật hoặc tự skip gate."""

import os
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from types import SimpleNamespace

import pytest
from fastapi import Depends, FastAPI, Header
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.engine import make_url
from sqlalchemy.orm import sessionmaker

from app.api.endpoints import medication as routes
from app.config import get_today
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.base import Base
from app.models.child import Child, ChildStatus, Parent
from app.models.medication import MedicationLog, MedicationRequest, MedicationRequestStatus as State
from app.models.user import Class_, School, Teacher, User, UserRole


@pytest.fixture()
def pg(monkeypatch):
    raw_url = os.getenv("MEDICATION_TEST_DATABASE_URL")
    if not raw_url:
        raise RuntimeError("Cần MEDICATION_TEST_DATABASE_URL trỏ tới PostgreSQL test_db riêng")
    url = make_url(raw_url)
    if url.get_backend_name() != "postgresql" or url.database != "test_db" or url.host not in {"localhost", "127.0.0.1", "::1"}:
        raise RuntimeError("Chỉ cho phép test_db trên PostgreSQL localhost, không dùng DB production")
    schema = f"medication_test_{uuid.uuid4().hex}"
    admin = create_engine(url)
    with admin.begin() as connection:
        connection.exec_driver_sql(f'CREATE SCHEMA "{schema}"')
    engine = create_engine(url, connect_args={"options": f"-csearch_path={schema}"})
    factory = sessionmaker(engine, expire_on_commit=False)
    statements, notifications = [], []
    event.listen(engine, "before_cursor_execute", lambda conn, cursor, statement, params, ctx, many: statements.append(statement))
    monkeypatch.setattr(routes.send_medication_confirmed_notification, "delay", lambda *args: notifications.append(args))
    try:
        Base.metadata.create_all(engine)
        with factory() as db:
            school = School(name="Trường kiểm thử", code=uuid.uuid4().hex[:12])
            db.add(school)
            db.flush()
            class_ = Class_(school_id=school.school_id, name="Mầm A")
            parent = Parent(full_name="Phụ huynh kiểm thử", phone="0912345678")
            db.add_all([class_, parent])
            db.flush()
            child = Child(full_name="Bé kiểm thử", parent=parent, class_id=class_.class_id, status=ChildStatus.ENROLLED)
            teachers = [Teacher(full_name=f"Cô {index}", school_id=school.school_id,
                                class_id=class_.class_id, email=f"test{index}@example.test") for index in range(2)]
            db.add_all([child, *teachers])
            db.flush()
            users = [User(username=f"teacher{index}", password_hash="test-only", role=UserRole.TEACHER,
                          teacher_id=teacher.teacher_id) for index, teacher in enumerate(teachers)]
            owner = User(username="parent", password_hash="test-only", role=UserRole.PARENT, parent_id=parent.parent_id)
            db.add_all([*users, owner])
            db.flush()
            req = MedicationRequest(child_id=child.child_id, parent_id=parent.parent_id, class_id=class_.class_id,
                batch_id=uuid.uuid4(), start_date=get_today(), end_date=get_today(), request_date=get_today(),
                time_slot="08:30", medication_name="Thuốc theo đơn", dosage="5ml", status=State.PENDING,
                created_by_user_id=owner.user_id, created_by_role="parent")
            db.add(req)
            db.commit()
        app = FastAPI()
        app.include_router(routes.router, prefix="/api")

        def request_db():
            with factory() as db:
                yield db

        def actor(x_test_actor: uuid.UUID = Header(), db=Depends(get_db)):
            return db.get(User, x_test_actor)

        app.dependency_overrides[get_db] = request_db
        app.dependency_overrides[get_current_user] = actor
        yield SimpleNamespace(app=app, factory=factory, request_id=req.request_id,
                              teachers=[user.user_id for user in users], parent=owner.user_id, child_id=child.child_id,
                              notifications=notifications, statements=statements)
    finally:
        engine.dispose()
        # Chỉ xóa schema UUID do fixture này vừa tạo, không xóa table/schema sẵn có.
        with admin.begin() as connection:
            connection.exec_driver_sql(f'DROP SCHEMA "{schema}" CASCADE')
        admin.dispose()


def race(pg, second_action):
    barrier = Barrier(2)

    def call(action, actor):
        with TestClient(pg.app) as client:
            barrier.wait(timeout=10)
            headers = {"x-test-actor": str(actor)}
            if action == "legacy":
                return client.put(f"/api/teacher/medications/{pg.request_id}/confirm",
                    params={"date": str(get_today())}, json={"session": "morning"}, headers=headers)
            return client.post(f"/api/medication-requests/{pg.request_id}/{action}", headers=headers)

    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(call, "legacy", pg.teachers[0])
        second = pool.submit(call, second_action, pg.parent if second_action == "cancel" else pg.teachers[1])
        return first.result(timeout=20), second.result(timeout=20)


def test_two_confirmation_apis_cannot_give_the_same_dose_twice(pg):
    responses = race(pg, "confirm")
    assert sorted(response.status_code for response in responses) == [200, 409]
    with pg.factory() as db:
        req = db.get(MedicationRequest, pg.request_id)
        log = db.scalar(select(MedicationLog))
        assert req.status == State.GIVEN and log.is_given
        assert req.given_by_id == log.given_by_id
        assert db.scalar(select(func.count()).select_from(MedicationLog)) == 1
    assert len(pg.notifications) == 1
    assert any("FOR UPDATE OF medication_request" in sql for sql in pg.statements)


def test_confirmation_and_cancellation_cannot_both_succeed(pg):
    responses = race(pg, "cancel")
    assert sorted(response.status_code for response in responses) == [200, 400]
    with pg.factory() as db:
        req = db.get(MedicationRequest, pg.request_id)
        assert req.status in {State.GIVEN, State.CANCELLED}
        count = db.scalar(select(func.count()).select_from(MedicationLog))
        assert count == (1 if req.status == State.GIVEN else 0)
        assert len(pg.notifications) == count


def test_duplicate_batch_creation_has_one_atomic_winner(pg, monkeypatch):
    from app.core import storage

    image_id = uuid.uuid4()
    key = f"{pg.child_id}/{image_id}"

    def stat(bucket, object_name):
        assert bucket.endswith("-medication-requests") and object_name == key
        return SimpleNamespace(size=16, content_type="image/png", metadata={
            "x-amz-meta-child-id": str(pg.child_id), "x-amz-meta-uploader-id": str(pg.parent)})

    monkeypatch.setattr(storage, "minio_client", SimpleNamespace(stat_object=stat))
    barrier = Barrier(2)

    def create():
        with TestClient(pg.app) as client:
            barrier.wait(timeout=10)
            return client.post("/api/medication-requests", headers={"x-test-actor": str(pg.parent)}, json={
                "child_id": str(pg.child_id), "from_date": str(get_today()), "time_slots": ["09:30", "11:30"],
                "dosage": "5ml", "prescription_image_url": f"/api/medication-requests/attachments/{key}"})

    with ThreadPoolExecutor(max_workers=2) as pool:
        first, second = pool.submit(create), pool.submit(create)
        responses = first.result(timeout=20), second.result(timeout=20)
    assert sorted(response.status_code for response in responses) == [201, 409]
    with pg.factory() as db:
        assert db.scalar(select(func.count()).select_from(MedicationRequest)) == 3
