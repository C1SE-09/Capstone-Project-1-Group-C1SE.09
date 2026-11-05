"""Hồi quy Celery task thông báo cho "Phản hồi báo cáo".

Kiểm tra:
- Phụ huynh gửi phản hồi → push tới giáo viên (data.type = report_response).
- Giáo viên trả lời → push tới phụ huynh (data.type = report_response_reply).
- Không có device token → task không lỗi (best-effort).
- Token FCM không hợp lệ → bị xoá khỏi DB.
"""

import uuid
from datetime import date
from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.models import (
    Base,
    Child,
    Class_,
    DailyReport,
    DailyReportStatus,
    DeviceToken,
    Parent,
    ParentChild,
    ReportResponse,
    School,
    Teacher,
    User,
    UserRole,
)
from app.tasks import report_response_notifications as tasks

TODAY = date(2030, 1, 5)


@pytest.fixture()
def env(monkeypatch):
    engine = create_engine(
        "sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    tables = [
        Base.metadata.tables[name]
        for name in (
            "school", "class", "teacher", "parent", "child", "parent_child",
            "users", "daily_report", "activity_entry", "report_response",
            "voice_record", "voice_recording_session", "device_tokens",
        )
    ]
    Base.metadata.create_all(engine, tables=tables)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    db = factory()

    school = School(school_id=uuid.uuid4(), name="Trường A", code="A")
    class_ = Class_(class_id=uuid.uuid4(), school=school, name="Lớp A")
    parent = Parent(parent_id=uuid.uuid4(), full_name="Mẹ An", phone="0900000000")
    child = Child(
        child_id=uuid.uuid4(), full_name="Bé An", parent=parent, class_=class_
    )
    teacher = Teacher(
        teacher_id=uuid.uuid4(), full_name="Cô Mai", school=school, class_=class_,
        email="mai@example.test",
    )
    db.add_all([school, class_, parent, child, teacher])
    db.flush()
    db.add(ParentChild(child_id=child.child_id, parent_id=parent.parent_id))

    parent_user = User(
        user_id=uuid.uuid4(), username="parent", password_hash="x",
        role=UserRole.PARENT, parent_id=parent.parent_id,
    )
    teacher_user = User(
        user_id=uuid.uuid4(), username="teacher", password_hash="x",
        role=UserRole.TEACHER, teacher=teacher,
    )
    db.add_all([parent_user, teacher_user])
    db.flush()

    report = DailyReport(
        daily_report_id=uuid.uuid4(),
        child_id=child.child_id,
        teacher_id=teacher.teacher_id,
        report_date=TODAY,
        status=DailyReportStatus.SENT,
        summary_text="Bé An ăn khá ngoan",
    )
    db.add(report)
    db.flush()

    db.add_all([
        DeviceToken(
            device_token_id=uuid.uuid4(), user_id=teacher_user.user_id,
            token="teacher-token", device_type="android",
        ),
        DeviceToken(
            device_token_id=uuid.uuid4(), user_id=parent_user.user_id,
            token="parent-token", device_type="android",
        ),
    ])
    db.commit()

    sent = []

    def fake_send_push(*, token, title, body, data=None, channel_id=None):
        sent.append({"token": token, "title": title, "body": body, "data": data})
        return "msg-id"

    monkeypatch.setattr(tasks, "send_push_notification", fake_send_push)

    state = SimpleNamespace(
        db=db, factory=factory, child=child, parent_user=parent_user,
        teacher_user=teacher_user, report=report, sent=sent,
    )
    yield state
    db.close()
    engine.dispose()


def _make_response(env, role="parent"):
    with env.factory() as db:
        row = ReportResponse(
            daily_report_id=env.report.daily_report_id,
            child_id=env.child.child_id,
            author_user_id=(
                env.parent_user.user_id if role == "parent" else env.teacher_user.user_id
            ),
            author_role=role,
            content="Bé An sốt nhẹ",
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        return row


def test_parent_response_notifies_teacher(env):
    row = _make_response(env, "parent")
    result = tasks._deliver_response_to_teacher(env.db, str(row.response_id))
    assert result["sent"] == 1
    payload = env.sent[0]
    assert payload["token"] == "teacher-token"
    assert payload["data"]["type"] == "report_response"
    assert payload["data"]["report_id"] == str(env.report.daily_report_id)
    assert payload["data"]["child_id"] == str(env.child.child_id)
    assert "Mẹ An" in payload["body"]


def test_teacher_reply_notifies_parent(env):
    row = _make_response(env, "teacher")
    result = tasks._deliver_reply_to_parent(env.db, str(row.response_id))
    assert result["sent"] == 1
    payload = env.sent[0]
    assert payload["token"] == "parent-token"
    assert payload["data"]["type"] == "report_response_reply"
    assert "Cô Mai" in payload["body"]


def test_invalid_response_id_is_handled(env):
    result = tasks._deliver_response_to_teacher(env.db, "not-a-uuid")
    assert result["reason"] == "invalid_response_id"
    assert env.sent == []


def test_unknown_response_id_is_handled(env):
    result = tasks._deliver_response_to_teacher(env.db, str(uuid.uuid4()))
    assert result["reason"] == "response_not_found"
    assert env.sent == []


def test_no_device_token_does_not_fail(env, monkeypatch):
    """Không có token → task trả về lý do, không raise."""
    with env.factory() as db:
        for token in db.query(DeviceToken).all():
            db.delete(token)
        db.commit()

    row = _make_response(env, "parent")
    result = tasks._deliver_response_to_teacher(env.db, str(row.response_id))
    assert result["reason"] == "no_device_tokens"
    assert env.sent == []


def test_push_failure_does_not_break_other_tokens(env, monkeypatch):
    """1 token lỗi không được chặn token còn lại."""
    calls = []

    def flaky_send(*, token, title, body, data=None, channel_id=None):
        calls.append(token)
        if token == "teacher-token":
            raise RuntimeError("FCM down")
        return "msg-id"

    monkeypatch.setattr(tasks, "send_push_notification", flaky_send)
    row = _make_response(env, "parent")
    result = tasks._deliver_response_to_teacher(env.db, str(row.response_id))
    assert result["sent"] == 0
    assert result["failed"] == 1
    assert "teacher-token" in calls


def test_invalid_token_is_removed_from_db(env, monkeypatch):
    class UnregisteredError(Exception):
        pass

    def fake_send(*, token, title, body, data=None, channel_id=None):
        raise UnregisteredError("Requested entity was not found")

    monkeypatch.setattr(tasks, "send_push_notification", fake_send)
    monkeypatch.setattr(tasks, "is_invalid_token", lambda err: True)

    row = _make_response(env, "parent")
    result = tasks._deliver_response_to_teacher(env.db, str(row.response_id))
    assert result["removed"] == 1
    with env.factory() as db:
        assert db.query(DeviceToken).filter(
            DeviceToken.token == "teacher-token"
        ).first() is None
