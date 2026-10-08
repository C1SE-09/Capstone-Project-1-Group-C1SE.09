"""Unit tests cho task gửi push notification (mock DB + mock FCM).

Không cần Postgres/Firebase thật: session và hàm gửi đều được thay bằng
mock, đúng phong cách tests/test_schedule.py.
"""

import uuid
from datetime import date
from unittest.mock import MagicMock

from app.models.device_token import DeviceToken
from app.models.report import DailyReport
from app.models.user import Teacher
from app.tasks import notifications as notifications_task

REPORT_ID = uuid.UUID("44444444-0000-0000-0000-000000000001")


class UnregisteredError(Exception):
    """Giả lập lỗi FCM: token đã bị gỡ khỏi thiết bị."""


class InvalidArgumentError(Exception):
    """Giả lập lỗi FCM: token không đúng định dạng."""


def _make_report():
    report = MagicMock()
    report.daily_report_id = REPORT_ID
    report.child_id = uuid.uuid4()
    report.teacher_id = uuid.uuid4()
    report.report_date = date(2026, 10, 8)
    child = MagicMock()
    child.parent_id = uuid.uuid4()
    child.full_name = "Lê Ngọc Ánh"
    child.nickname = None
    report.child = child
    return report


def _make_db(*, report=None, teacher=None, tokens=()):
    """DB giả: định tuyến db.query(Model) tới kết quả mong muốn."""
    db = MagicMock()

    def query(model):
        result = MagicMock()
        if model is DailyReport:
            result.filter.return_value.first.return_value = report
        elif model is Teacher:
            result.filter.return_value.first.return_value = teacher
        elif model is DeviceToken:
            result.join.return_value.filter.return_value.all.return_value = list(
                tokens
            )
        return result

    db.query.side_effect = query
    return db


def _make_token(value):
    token = MagicMock()
    token.token = value
    return token


def test_sends_to_all_household_tokens(monkeypatch):
    report = _make_report()
    teacher = MagicMock()
    teacher.full_name = "Cô Nguyễn Thị Mai"
    tokens = [_make_token("tok-1"), _make_token("tok-2")]
    db = _make_db(report=report, teacher=teacher, tokens=tokens)

    calls = []

    def fake_send(**kwargs):
        calls.append(kwargs)
        return "message-id"

    monkeypatch.setattr(notifications_task, "send_push_notification", fake_send)

    result = notifications_task._deliver_report_notification(db, str(REPORT_ID))

    assert result == {"sent": 2, "removed": 0}
    assert [call["token"] for call in calls] == ["tok-1", "tok-2"]
    assert "Lê Ngọc Ánh" in calls[0]["title"]
    assert "Cô Nguyễn Thị Mai" in calls[0]["body"]
    assert calls[0]["data"]["report_id"] == str(REPORT_ID)
    db.commit.assert_called()


def test_removes_invalid_token(monkeypatch):
    report = _make_report()
    token = _make_token("tok-dead")
    db = _make_db(report=report, teacher=None, tokens=[token])

    def fail(**kwargs):
        raise UnregisteredError("token gone")

    monkeypatch.setattr(notifications_task, "send_push_notification", fail)

    result = notifications_task._deliver_report_notification(db, str(REPORT_ID))

    assert result == {"sent": 0, "removed": 1}
    db.delete.assert_called_once_with(token)
    db.commit.assert_called()


def test_removes_malformed_token(monkeypatch):
    """Token rác: FCM trả InvalidArgumentError nhắc tới registration token."""
    report = _make_report()
    token = _make_token("tok-malformed")
    db = _make_db(report=report, teacher=None, tokens=[token])

    def fail(**kwargs):
        raise InvalidArgumentError(
            "The registration token is not a valid FCM registration token"
        )

    monkeypatch.setattr(notifications_task, "send_push_notification", fail)

    result = notifications_task._deliver_report_notification(db, str(REPORT_ID))

    assert result == {"sent": 0, "removed": 1}
    db.delete.assert_called_once_with(token)


def test_generic_invalid_argument_keeps_token(monkeypatch):
    """InvalidArgumentError không nói về token (lỗi message) thì KHÔNG xoá token."""
    report = _make_report()
    token = _make_token("tok-ok")
    db = _make_db(report=report, teacher=None, tokens=[token])

    def fail(**kwargs):
        raise InvalidArgumentError("Invalid message payload")

    monkeypatch.setattr(notifications_task, "send_push_notification", fail)

    result = notifications_task._deliver_report_notification(db, str(REPORT_ID))

    assert result == {"sent": 0, "removed": 0}
    db.delete.assert_not_called()


def test_one_failed_send_does_not_stop_others(monkeypatch):
    report = _make_report()
    tokens = [_make_token("tok-1"), _make_token("tok-2")]
    db = _make_db(report=report, teacher=None, tokens=tokens)
    state = {"calls": 0}

    def flaky(**kwargs):
        state["calls"] += 1
        if state["calls"] == 1:
            raise TimeoutError("FCM timeout")
        return "ok"

    monkeypatch.setattr(notifications_task, "send_push_notification", flaky)

    result = notifications_task._deliver_report_notification(db, str(REPORT_ID))

    assert result == {"sent": 1, "removed": 0}
    assert state["calls"] == 2


def test_no_tokens_is_noop(monkeypatch):
    report = _make_report()
    db = _make_db(report=report, teacher=None, tokens=[])

    def should_not_run(**kwargs):
        raise AssertionError("không được gửi khi chưa có device token")

    monkeypatch.setattr(
        notifications_task, "send_push_notification", should_not_run
    )

    result = notifications_task._deliver_report_notification(db, str(REPORT_ID))

    assert result == {"sent": 0, "removed": 0, "reason": "no_device_tokens"}


def test_report_not_found():
    db = _make_db(report=None)

    result = notifications_task._deliver_report_notification(db, str(REPORT_ID))

    assert result["reason"] == "report_not_found"
    db.commit.assert_not_called()


def test_invalid_report_id():
    db = _make_db(report=None)

    result = notifications_task._deliver_report_notification(db, "not-a-uuid")

    assert result["reason"] == "invalid_report_id"
    db.commit.assert_not_called()


def test_queue_report_notification_counts_and_queues(monkeypatch):
    """Helper dùng chung: đếm token phụ huynh và đẩy job vào Celery."""
    from app.api import teacher as teacher_module

    report = _make_report()
    db = MagicMock()
    queued = []
    monkeypatch.setattr(
        teacher_module.send_report_notifications,
        "delay",
        lambda report_id: queued.append(report_id),
    )
    monkeypatch.setattr(
        teacher_module, "parent_device_tokens", lambda db, parent_id: [1, 2]
    )

    count = teacher_module._queue_report_notification(db, report, report.child)

    assert count == 2
    assert queued == [str(REPORT_ID)]


def test_publish_report_queues_notification(monkeypatch):
    """Bấm 'Gửi báo cáo' trong app gọi /publish — phải phát thông báo."""
    from app.api import teacher as teacher_module
    from app.models.report import DailyReportStatus

    report = _make_report()
    db = _make_db(report=report, teacher=None)
    queued = []
    monkeypatch.setattr(
        teacher_module,
        "_queue_report_notification",
        lambda db, r, child: queued.append(r.daily_report_id) or 5,
    )

    result = teacher_module.publish_report(
        report_id=REPORT_ID,
        teacher_id=report.teacher_id,
        db=db,
    )

    assert result["status"] == DailyReportStatus.PUBLISHED.value
    assert queued == [REPORT_ID]
