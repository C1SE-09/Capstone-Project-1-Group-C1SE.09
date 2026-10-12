"""
tests/test_bug_report_notifications.py
=======================================
Unit tests cho Celery pure delivery functions (B-04).

Pattern giống ``test_notifications.py``:
    - DB là ``MagicMock`` (không cần Postgres thật)
    - FCM/email được monkey-patched
    - Verify inputs/outputs, không test infrastructure

Dùng ``ModelRouter`` để route ``db.query(Model)`` tới đúng dữ liệu,
thay vì dùng counter dễ bị trôi khi function query nhiều lần.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock

import pytest
from app.models.bug_report import BugCategory, BugReport, BugSeverity, BugStatus
from app.models.device_token import DeviceToken
from app.models.user import User, UserRole
from app.tasks import bug_report_notifications as brn

REPORT_ID = uuid.UUID("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
USER_ID = uuid.UUID("11111111-2222-3333-4444-555555555555")
ADMIN1_ID = uuid.UUID("66666666-7777-8888-9999-aaaaaaaaaaaa")
ADMIN2_ID = uuid.UUID("bbbbbbbb-cccc-dddd-eeee-ffffffffffff")


# ===========================================================================
# ModelRouter - smart DB mock routing by class
# ===========================================================================


class ModelRouter:
    """Routes ``db.query(Model)`` tới data đúng theo model class.

    Tránh được problem: function query nhiều lần liên tiếp → counter trôi.

    Usage:
        router = ModelRouter(mock_db)
        router.set(BugReport, report_obj)
        router.set(User, [admin1, admin2])  # all()
        router.set(DeviceToken, [token1])  # all()
        # Now:
        #   db.query(BugReport).filter().first() → report_obj
        #   db.query(User).filter().all() → [admin1, admin2]
        #   db.query(DeviceToken).filter().all() → [token1]
    """

    def __init__(self, db):
        self._db = db
        self._models: dict[type, object] = {}

        def query(model_cls):
            result = MagicMock()
            item = self._models.get(model_cls)
            if isinstance(item, list):
                result.filter.return_value.all.return_value = list(item)
                result.all.return_value = list(item)
                # Also support .join().filter().all() chain
                result.join.return_value.filter.return_value.all.return_value = list(item)
            elif item is None:
                result.filter.return_value.all.return_value = []
                result.filter.return_value.first.return_value = None
                result.join.return_value.filter.return_value.all.return_value = []
            else:
                result.filter.return_value.first.return_value = item
                result.first.return_value = item
                result.join.return_value.filter.return_value.first.return_value = item
            return result

        db.query.side_effect = query

    def set(self, model_cls, value):
        """Set data trả về cho model_cls. value = single obj hoặc list."""
        self._models[model_cls] = value


# ===========================================================================
# Factories
# ===========================================================================


def _make_report(**overrides) -> BugReport:
    report = MagicMock(spec=BugReport)
    report.bug_report_id = overrides.get("bug_report_id", REPORT_ID)
    report.user_id = overrides.get("user_id", USER_ID)
    report.title = overrides.get("title", "App crash on save")
    report.description = overrides.get("description", "Khi bam Save app thoat")
    report.category = overrides.get("category", BugCategory.CRASH)
    report.severity = overrides.get("severity", BugSeverity.HIGH)
    report.status = overrides.get("status", BugStatus.OPEN)
    report.app_version = "1.0.0"
    report.build_number = "42"
    report.os_version = "Android 14"
    report.device_model = "Pixel 7"
    report.network_type = "wifi"
    report.teacher_id = None
    report.created_at = overrides.get(
        "created_at", datetime(2026, 10, 12, tzinfo=timezone.utc)
    )
    report.updated_at = report.created_at
    report.resolved_at = overrides.get("resolved_at", None)
    return report


def _make_user(user_id, role, teacher_email=None, parent_email=None, full_name=None):
    user = MagicMock(spec=User)
    user.user_id = user_id
    user.role = role
    user.username = f"user_{user_id.hex[:8]}"

    user.teacher = MagicMock() if teacher_email else None
    if user.teacher is not None:
        user.teacher.email = teacher_email
        user.teacher.full_name = full_name or f"Teacher {user.username}"

    user.parent = MagicMock() if parent_email else None
    if user.parent is not None:
        user.parent.email = parent_email
        user.parent.full_name = full_name or f"Parent {user.username}"
    return user


def _make_token(value, user_id):
    token = MagicMock(spec=DeviceToken)
    token.token = value
    token.user_id = user_id
    return token


# ===========================================================================
# Fixtures
# ===========================================================================


@pytest.fixture()
def mock_db():
    db = MagicMock()
    db.add = MagicMock()
    db.commit = MagicMock()
    db.rollback = MagicMock()
    db.delete = MagicMock()
    return db


@pytest.fixture()
def router(mock_db):
    """Pre-configured router cho notification tests."""
    return ModelRouter(mock_db)


# ===========================================================================
# TestDeliveAdminNotification
# ===========================================================================


class TestDeliveAdminNotification:
    """_deliver_admin_notification - notify admin khi có report mới."""

    def test_sends_to_all_admin_tokens(self, router, monkeypatch):
        """Push tới tất cả device tokens của admin."""
        report = _make_report()
        admin1 = _make_user(ADMIN1_ID, UserRole.ADMIN)
        admin2 = _make_user(ADMIN2_ID, UserRole.ADMIN)
        tokens = [
            _make_token("admin1_tok", ADMIN1_ID),
            _make_token("admin2_tok", ADMIN2_ID),
        ]
        router.set(BugReport, report)
        # User query: when called for admins (.all()), returns [admin1, admin2]
        router.set(User, [admin1, admin2])
        router.set(DeviceToken, tokens)

        # Skip email side - directly provide empty list
        monkeypatch.setattr(brn, "_get_admin_emails", lambda db: [])

        fcm_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification",
            lambda **kw: fcm_calls.append(kw) or "msg_id",
        )
        monkeypatch.setattr(brn, "send_test_email", lambda **kw: None)

        result = brn._deliver_admin_notification(router._db, str(REPORT_ID))

        assert result["report_found"] is True
        assert result["push_sent"] == 2
        assert len(fcm_calls) == 2
        tokens_sent = sorted(c["token"] for c in fcm_calls)
        assert tokens_sent == ["admin1_tok", "admin2_tok"]

    def test_push_data_has_required_fields(self, router, monkeypatch):
        """FCM data payload phải có type + bug_report_id + severity + category."""
        report = _make_report()
        admin = _make_user(ADMIN1_ID, UserRole.ADMIN)
        token = _make_token("tok", ADMIN1_ID)
        router.set(BugReport, report)
        router.set(User, [admin])
        router.set(DeviceToken, [token])
        monkeypatch.setattr(brn, "_get_admin_emails", lambda db: [])

        fcm_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification",
            lambda **kw: fcm_calls.append(kw) or "msg_id",
        )
        monkeypatch.setattr(brn, "send_test_email", lambda **kw: None)

        brn._deliver_admin_notification(router._db, str(REPORT_ID))

        assert len(fcm_calls) == 1
        data = fcm_calls[0]["data"]
        assert data["type"] == "bug_report_new"
        assert data["bug_report_id"] == str(REPORT_ID)
        assert data["severity"] == "high"
        assert data["category"] == "crash"

    def test_critical_severity_in_title(self, router, monkeypatch):
        """[CRITICAL] prefix trong title khi severity=critical."""
        report = _make_report(severity=BugSeverity.CRITICAL)
        admin = _make_user(ADMIN1_ID, UserRole.ADMIN)
        token = _make_token("tok", ADMIN1_ID)
        router.set(BugReport, report)
        router.set(User, [admin])
        router.set(DeviceToken, [token])
        monkeypatch.setattr(brn, "_get_admin_emails", lambda db: [])

        fcm_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification",
            lambda **kw: fcm_calls.append(kw) or "msg_id",
        )
        monkeypatch.setattr(brn, "send_test_email", lambda **kw: None)

        brn._deliver_admin_notification(router._db, str(REPORT_ID))

        assert "[CRITICAL]" in fcm_calls[0]["title"]

    def test_removes_invalid_token(self, router, monkeypatch):
        """Invalid FCM token tự xóa khỏi DB."""
        report = _make_report()
        admin = _make_user(ADMIN1_ID, UserRole.ADMIN)
        bad_token = _make_token("bad_tok", ADMIN1_ID)
        good_token = _make_token("good_tok", ADMIN1_ID)
        router.set(BugReport, report)
        router.set(User, [admin])
        router.set(DeviceToken, [bad_token, good_token])
        monkeypatch.setattr(brn, "_get_admin_emails", lambda db: [])

        def fail_on_bad(**kw):
            if kw["token"] == "bad_tok":
                from firebase_admin.exceptions import (
                    InvalidArgumentError as _IA,
                )

                raise _IA("registration token is not a valid FCM registration token")
            return "msg_id"

        monkeypatch.setattr(brn, "send_push_notification", fail_on_bad)
        monkeypatch.setattr(brn, "send_test_email", lambda **kw: None)

        result = brn._deliver_admin_notification(router._db, str(REPORT_ID))

        assert result["push_sent"] == 1
        assert result["push_removed"] == 1
        assert router._db.delete.called

    def test_email_sent_to_admin_via_auto_detect(self, router, monkeypatch):
        """Email sent tới admin (fallback tự tìm admin có email)."""
        report = _make_report()
        admin = _make_user(
            ADMIN1_ID, UserRole.ADMIN, teacher_email="admin1@kinderlog.app"
        )
        router.set(BugReport, report)
        router.set(User, [admin])
        router.set(DeviceToken, [])

        email_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification", lambda **kw: "msg_id"
        )
        monkeypatch.setattr(
            brn, "send_test_email", lambda **kw: email_calls.append(kw)
        )
        monkeypatch.setattr(brn.settings, "bug_report_notify_email", "")

        brn._deliver_admin_notification(router._db, str(REPORT_ID))

        assert len(email_calls) == 1
        assert email_calls[0]["to_email"] == "admin1@kinderlog.app"
        assert "Bug Report moi" in email_calls[0]["subject"]

    def test_email_uses_config_override(self, router, monkeypatch):
        """Nếu settings.bug_report_notify_email set → dùng nó."""
        report = _make_report()
        router.set(BugReport, report)
        # User list doesn't matter when config override is set
        router.set(User, [])

        email_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification", lambda **kw: "msg_id"
        )
        monkeypatch.setattr(
            brn, "send_test_email", lambda **kw: email_calls.append(kw)
        )
        monkeypatch.setattr(
            brn.settings,
            "bug_report_notify_email",
            "ops@kinderlog.app,dev@kinderlog.app",
        )

        brn._deliver_admin_notification(router._db, str(REPORT_ID))

        recipients = sorted(e["to_email"] for e in email_calls)
        assert recipients == ["dev@kinderlog.app", "ops@kinderlog.app"]

    def test_invalid_report_id(self, mock_db):
        """Invalid UUID → invalid_report_id, không raise."""
        result = brn._deliver_admin_notification(mock_db, "not-a-uuid")
        assert result["report_found"] is False
        assert result["reason"] == "invalid_report_id"

    def test_report_not_found(self, router):
        """UUID hợp lệ nhưng report không tồn tại."""
        router.set(BugReport, None)
        result = brn._deliver_admin_notification(
            router._db, "00000000-0000-0000-0000-000000000000"
        )
        assert result["report_found"] is False
        assert result["reason"] == "report_not_found"


# ===========================================================================
# TestDeliveUserNotification
# ===========================================================================


class TestDeliveUserNotification:
    """_deliver_user_notification - notify user khi admin đổi status."""

    def test_sends_to_user_tokens(self, router, monkeypatch):
        """Push tới device tokens của user đã gửi report."""
        report = _make_report()
        user = _make_user(USER_ID, UserRole.TEACHER, teacher_email="user@x.com")
        _admin = _make_user(ADMIN1_ID, UserRole.ADMIN, teacher_email="admin@x.com")
        tokens = [
            _make_token("user_tok1", USER_ID),
            _make_token("user_tok2", USER_ID),
        ]
        # Note: BUG_REPORT_NOTIFY_EMAIL config takes priority for emails,
        # so we set it to empty to test user-specific email flow.
        router.set(BugReport, report)
        # User query: when called .first() returns the matching user.
        # For user-notification flow, _deliver calls query(User) twice:
        # once for submitter (first), once for admin (first).
        # We need to handle this — see test_push_data_includes_status_transition
        # for a pattern. For this test, just use config override for email.
        router.set(User, user)  # For .first() (submitter)
        router.set(DeviceToken, tokens)

        fcm_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification",
            lambda **kw: fcm_calls.append(kw) or "msg_id",
        )
        monkeypatch.setattr(brn, "send_test_email", lambda **kw: None)

        result = brn._deliver_user_notification(
            router._db,
            report_id=str(REPORT_ID),
            old_status_value="open",
            new_status_value="in_progress",
            admin_comment="Dang xu ly",
            admin_user_id=str(ADMIN1_ID),
        )

        assert result["report_found"] is True
        assert result["push_sent"] == 2
        assert all(c["token"].startswith("user_tok") for c in fcm_calls)

    def test_push_data_includes_status_transition(self, router, monkeypatch):
        """FCM data có old_status + new_status + admin_comment."""
        report = _make_report()
        user = _make_user(USER_ID, UserRole.TEACHER, teacher_email="u@x.com")
        token = _make_token("user_tok", USER_ID)

        router.set(BugReport, report)
        router.set(User, user)
        router.set(DeviceToken, [token])

        fcm_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification",
            lambda **kw: fcm_calls.append(kw) or "msg_id",
        )
        monkeypatch.setattr(brn, "send_test_email", lambda **kw: None)

        brn._deliver_user_notification(
            router._db,
            report_id=str(REPORT_ID),
            old_status_value="in_progress",
            new_status_value="resolved",
            admin_comment="Fixed in commit abc",
            admin_user_id=str(ADMIN1_ID),
        )

        assert len(fcm_calls) == 1
        data = fcm_calls[0]["data"]
        assert data["type"] == "bug_report_updated"
        assert data["old_status"] == "in_progress"
        assert data["new_status"] == "resolved"
        assert data["admin_comment"] == "Fixed in commit abc"

    def test_resolved_status_vietnamese_title(self, router, monkeypatch):
        """Status=resolved → title có 'Da giai quyet'."""
        report = _make_report()
        user = _make_user(USER_ID, UserRole.TEACHER, teacher_email="u@x.com")
        token = _make_token("user_tok", USER_ID)

        router.set(BugReport, report)
        router.set(User, user)
        router.set(DeviceToken, [token])

        fcm_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification",
            lambda **kw: fcm_calls.append(kw) or "msg_id",
        )
        monkeypatch.setattr(brn, "send_test_email", lambda **kw: None)

        brn._deliver_user_notification(
            router._db,
            report_id=str(REPORT_ID),
            old_status_value="in_progress",
            new_status_value="resolved",
            admin_comment="OK",
            admin_user_id=str(ADMIN1_ID),
        )

        assert "Da giai quyet" in fcm_calls[0]["title"]

    def test_user_without_email_skips_email(self, router, monkeypatch):
        """User không có Teacher/Parent email → không gửi email."""
        report = _make_report()
        user = _make_user(USER_ID, UserRole.TEACHER, teacher_email=None)
        token = _make_token("user_tok", USER_ID)

        router.set(BugReport, report)
        router.set(User, user)
        router.set(DeviceToken, [token])

        email_calls = []
        fcm_calls = []
        monkeypatch.setattr(
            brn, "send_push_notification",
            lambda **kw: fcm_calls.append(kw) or "msg_id",
        )
        monkeypatch.setattr(
            brn, "send_test_email", lambda **kw: email_calls.append(kw)
        )

        result = brn._deliver_user_notification(
            router._db,
            report_id=str(REPORT_ID),
            old_status_value="open",
            new_status_value="resolved",
            admin_comment="OK",
            admin_user_id=str(ADMIN1_ID),
        )

        assert len(email_calls) == 0
        assert result["emails_sent"] == 0
        assert len(fcm_calls) == 1
        assert result["push_sent"] == 1

    def test_invalid_ids(self, mock_db):
        """Invalid UUID → invalid_id."""
        result = brn._deliver_user_notification(
            mock_db,
            report_id="not-uuid",
            old_status_value="open",
            new_status_value="resolved",
            admin_comment="",
            admin_user_id=str(ADMIN1_ID),
        )
        assert result["report_found"] is False
        assert result["reason"] == "invalid_id"


# ===========================================================================
# TestEmailTemplates
# ===========================================================================


class TestEmailTemplates:
    """Email template helpers."""

    def test_admin_email_includes_severity_and_title(self):
        report = _make_report()
        submitter = _make_user(
            USER_ID, UserRole.TEACHER, teacher_email="u@x.com", full_name="Co Mai"
        )

        subject, body = brn._build_admin_email(report, submitter)

        assert "Bug Report moi" in subject
        assert "App crash on save" in subject
        assert "Co Mai" in body
        assert "u@x.com" in body
        assert "HIGH" in body or "high" in body.lower()
        assert report.description in body
        assert str(REPORT_ID) in body

    def test_user_email_status_transition(self):
        report = _make_report()
        user = _make_user(
            USER_ID, UserRole.TEACHER, teacher_email="u@x.com", full_name="Co Lan"
        )

        subject, body = brn._build_user_email(
            report,
            user,
            old_status=BugStatus.OPEN,
            new_status=BugStatus.RESOLVED,
            admin_comment="Da fix xong",
            admin_name="Admin Nguyen",
        )

        assert "Da giai quyet" in subject
        assert "Moi tiep nhan" in body
        assert "Da giai quyet" in body
        assert "Admin Nguyen" in body
        assert "Da fix xong" in body

    def test_user_email_no_address_returns_empty(self):
        """User không có email → ('', '') để skip."""
        report = _make_report()
        user = _make_user(USER_ID, UserRole.TEACHER)  # no email

        subject, body = brn._build_user_email(
            report,
            user,
            old_status=BugStatus.OPEN,
            new_status=BugStatus.IN_PROGRESS,
            admin_comment="",
            admin_name="Admin",
        )
        assert subject == ""
        assert body == ""


# ===========================================================================
# TestSafeDispatch
# ===========================================================================


class TestSafeDispatch:
    """_safe_dispatch_celery không bao giờ raise."""

    def test_dispatch_called(self):
        from app.api.endpoints.bug_reports import _safe_dispatch_celery

        called = []

        def fake_delay(arg):
            called.append(arg)
            return "result"

        _safe_dispatch_celery(fake_delay, "test_arg")
        assert called == ["test_arg"]

    def test_dispatch_exception_logged_not_raised(self):
        from app.api.endpoints.bug_reports import _safe_dispatch_celery

        def fail_delay(arg):
            raise RuntimeError("Redis down")

        # Should NOT raise
        _safe_dispatch_celery(fail_delay, "test_arg")
