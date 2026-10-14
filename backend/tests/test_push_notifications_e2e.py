"""Kiểm thử E2E và Toàn Diện Toàn Bộ Kịch Bản Push Notification trên Backend.

Xác thực trực tiếp từ các module chính của hệ thống:
- app.services.notification_service
- app.tasks.notifications
- app.api.teacher
"""

from __future__ import annotations

import time
import uuid
from datetime import date
from unittest.mock import MagicMock, patch

from app.api import teacher as teacher_api
from app.models.device_token import DeviceToken
from app.models.report import DailyReport, DailyReportStatus
from app.models.user import Teacher
from app.services.notification_service import send_push_notification
from app.tasks.notifications import _deliver_report_notification
from firebase_admin import messaging

REPORT_ID = uuid.UUID("11111111-2222-3333-4444-555555555555")
CHILD_ID = uuid.UUID("66666666-7777-8888-9999-aaaaaaaaaaaa")
PARENT_ID = uuid.UUID("bbbbbbbb-cccc-dddd-eeee-ffffffffffff")
TEACHER_ID = uuid.UUID("12345678-1234-1234-1234-123456789abc")


def _create_mock_report(*, full_name="Nguyễn Nhật Nam", nickname="Bé Bo", report_date=None, status=DailyReportStatus.DRAFT):
    report = MagicMock()
    report.daily_report_id = REPORT_ID
    report.child_id = CHILD_ID
    report.teacher_id = TEACHER_ID
    report.report_date = report_date or date(2026, 10, 15)
    report.status = status
    report.published_at = None
    report.sent_at = None
    report.activities = []

    child = MagicMock()
    child.child_id = CHILD_ID
    child.parent_id = PARENT_ID
    child.full_name = full_name
    child.nickname = nickname
    report.child = child

    return report


def _create_mock_db(*, report=None, tokens=()):
    db = MagicMock()

    def query(model):
        res = MagicMock()
        if model is DailyReport:
            res.filter.return_value.first.return_value = report
        elif model is Teacher:
            teacher = MagicMock()
            teacher.teacher_id = TEACHER_ID
            teacher.full_name = "Cô Thuỳ Linh"
            res.filter.return_value.first.return_value = teacher
        elif model is DeviceToken:
            res.join.return_value.filter.return_value.all.return_value = list(tokens)
        return res

    db.query.side_effect = query
    return db


# ==============================================================================
# SCENARIO 1: GIÁO VIÊN GỬI BÁO CÁO MỚI (AC 1.1 + AC 2 + AC 4)
# ==============================================================================

class TestNewReportNotificationScenario:
    """Kịch bản gửi báo cáo lần đầu tiên tới phụ huynh."""

    @patch("app.tasks.notifications.send_push_notification")
    def test_new_report_notification_content_and_delivery(self, mock_send):
        """Xác thực: Title='KinderLog', Body ưu tiên Họ và tên bé, Type='report_sent'."""
        mock_send.return_value = "msg-123"

        report = _create_mock_report(full_name="Trần Nguyễn Hoàng Bách", nickname="Bé Sóc")
        token1 = MagicMock(token="token-dad-phone")
        token2 = MagicMock(token="token-mom-tablet")
        db = _create_mock_db(report=report, tokens=[token1, token2])

        result = _deliver_report_notification(db, str(REPORT_ID), is_update=False)

        assert result["sent"] == 2
        assert result["removed"] == 0
        assert mock_send.call_count == 2

        # Kiểm tra nội dung push
        first_call = mock_send.call_args_list[0].kwargs
        assert first_call["title"] == "KinderLog"
        assert first_call["body"] == "Báo cáo hàng ngày của Trần Nguyễn Hoàng Bách đã sẵn sàng"
        assert "Bé Sóc" not in first_call["body"]
        assert first_call["data"]["type"] == "report_sent"
        assert first_call["data"]["report_id"] == str(REPORT_ID)
        assert first_call["data"]["child_id"] == str(CHILD_ID)


# ==============================================================================
# SCENARIO 2: GIÁO VIÊN CHỈNH SỬA VÀ GỬI LẠI BÁO CÁO (AC 1.2)
# ==============================================================================

class TestUpdateReportNotificationScenario:
    """Kịch bản giáo viên sửa đổi báo cáo và phát thông báo cập nhật."""

    @patch("app.tasks.notifications.send_push_notification")
    def test_updated_report_notification_content_and_delivery(self, mock_send):
        """Xác thực: Title='KinderLog', Body='Báo cáo ngày dd/MM của [Họ tên] đã được cập nhật', Type='report_updated'."""
        mock_send.return_value = "msg-456"

        report = _create_mock_report(
            full_name="Lê Phạm Quỳnh Anh",
            nickname="Bé Thỏ",
            report_date=date(2026, 10, 15),
        )
        token = MagicMock(token="token-mom-phone")
        db = _create_mock_db(report=report, tokens=[token])

        result = _deliver_report_notification(db, str(REPORT_ID), is_update=True)

        assert result["sent"] == 1
        assert mock_send.call_count == 1

        call_kwargs = mock_send.call_args.kwargs
        assert call_kwargs["title"] == "KinderLog"
        assert call_kwargs["body"] == "Báo cáo ngày 15/10 của Lê Phạm Quỳnh Anh đã được cập nhật"
        assert call_kwargs["data"]["type"] == "report_updated"
        assert call_kwargs["data"]["report_id"] == str(REPORT_ID)


# ==============================================================================
# SCENARIO 3: CẤU HÌNH FCM HIGH PRIORITY, ÂM THANH MẶC ĐỊNH & SÁNG MÀN HÌNH (AC 2)
# ==============================================================================

class TestFCMMessageConfiguration:
    """Kiểm tra tin nhắn gửi đến Firebase Cloud Messaging."""

    @patch("app.services.notification_service.messaging.send")
    @patch("app.services.notification_service.get_firebase_app")
    def test_fcm_message_contains_wake_screen_and_sound_configs(self, mock_app, mock_send):
        """Xác thực: priority high, channel_id='kinderlog_reports', sound='default', visibility='public'."""
        mock_send.return_value = "projects/kinderlog/messages/fcm-msg-1"

        send_push_notification(
            token="test-device-token",
            title="KinderLog",
            body="Báo cáo hàng ngày của Bé A đã sẵn sàng",
            data={"type": "report_sent", "report_id": str(REPORT_ID)},
        )

        assert mock_send.call_count == 1
        message: messaging.Message = mock_send.call_args[0][0]

        # Kiểm tra Android Config
        assert message.android is not None
        assert message.android.priority == "high"
        assert message.android.notification.channel_id == "kinderlog_reports"
        assert message.android.notification.sound == "default"
        assert message.android.notification.default_sound is True
        assert message.android.notification.visibility == "public"

        # Kiểm tra iOS (APNS) Config
        assert message.apns is not None
        assert message.apns.payload.aps.sound == "default"


# ==============================================================================
# SCENARIO 4: DỌN DẸP TOKEN HẾT HẠN & CÔ LẬP LỖI THIẾT BỊ (AC 4)
# ==============================================================================

class TestTokenFaultTolerance:
    """Kiểm tra xử lý lỗi khi có token bị gỡ hoặc không hợp lệ."""

    def test_invalid_token_is_purged_without_breaking_other_devices(self):
        """Token lỗi bị xoá khỏi DB, token hợp lệ khác vẫn gửi thành công."""
        class UnregisteredError(Exception):
            pass

        token_alive = MagicMock(token="token-valid")
        token_dead = MagicMock(token="token-expired")

        report = _create_mock_report(full_name="Vũ Bảo Ngọc")
        db = _create_mock_db(report=report, tokens=[token_alive, token_dead])

        def mock_sender(token, title, body, data):
            if token == "token-expired":
                raise UnregisteredError("Token is unregistered")
            return "ok"

        with patch("app.tasks.notifications.send_push_notification", side_effect=mock_sender):
            result = _deliver_report_notification(db, str(REPORT_ID), is_update=False)

        assert result["sent"] == 1
        assert result["removed"] == 1
        db.delete.assert_called_once_with(token_dead)
        db.commit.assert_called_once()


# ==============================================================================
# SCENARIO 5: KIỂM TRA HIỆU NĂNG TẦNG BACKEND (< 500ms, ĐẢM BẢO SLA < 30s)
# ==============================================================================

class TestSLAAndPerformance:
    """Đo thời gian thực thi của tầng Backend."""

    @patch("app.tasks.notifications.send_push_notification", return_value="fcm-ok")
    def test_backend_execution_time_under_500ms(self, mock_send):
        tokens = [MagicMock(token=f"device-{i}") for i in range(15)]
        report = _create_mock_report()
        db = _create_mock_db(report=report, tokens=tokens)

        start = time.perf_counter()
        result = _deliver_report_notification(db, str(REPORT_ID), is_update=False)
        duration = time.perf_counter() - start

        assert result["sent"] == 15
        assert duration < 0.5, f"Backend execution took {duration:.3f}s (> 0.5s)"


# ==============================================================================
# SCENARIO 6: KIỂM THỬ TÍCH HỢP TẦNG API GIÁO VIÊN (TEACHER API -> NOTIFICATION)
# ==============================================================================

class TestTeacherApiIntegration:
    """Kiểm tra luồng API: publish / send nhận diện đúng cờ is_update."""

    def test_publish_report_new_queues_notification_with_is_update_false(self, monkeypatch):
        """Lần đầu publish -> is_update=False."""
        report = _create_mock_report(status=DailyReportStatus.DRAFT)
        report.published_at = None
        db = _create_mock_db(report=report)

        queued_tasks = []
        monkeypatch.setattr(
            teacher_api,
            "_queue_report_notification",
            lambda db, r, child, **kwargs: queued_tasks.append(kwargs.get("is_update")),
        )

        teacher_api.publish_report(report_id=REPORT_ID, teacher_id=TEACHER_ID, db=db)

        assert len(queued_tasks) == 1
        assert queued_tasks[0] is False

    def test_publish_report_already_published_queues_notification_with_is_update_true(self, monkeypatch):
        """Đã từng publish trước đó -> is_update=True."""
        report = _create_mock_report(status=DailyReportStatus.PUBLISHED)
        report.published_at = date(2026, 10, 14)
        db = _create_mock_db(report=report)

        queued_tasks = []
        monkeypatch.setattr(
            teacher_api,
            "_queue_report_notification",
            lambda db, r, child, **kwargs: queued_tasks.append(kwargs.get("is_update")),
        )

        teacher_api.publish_report(report_id=REPORT_ID, teacher_id=TEACHER_ID, db=db)

        assert len(queued_tasks) == 1
        assert queued_tasks[0] is True
