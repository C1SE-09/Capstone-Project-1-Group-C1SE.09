"""Thông báo cho phụ huynh khi report được gửi.

Hiện tại: LoggingNotificationService - ghi log ý định gửi, ko đẩy push thật.
"""

from __future__ import annotations

import logging
from typing import Protocol

logger = logging.getLogger(__name__)


class NotificationService(Protocol):

    def notify_report_sent(
        self,
        *,
        report_id: str,
        child_id: str,
        child_name: str,
        linked_parents: int,
    ) -> int:
        """Gửi tb. Trả về số tb đã gửi thành công."""
        ...


class LoggingNotificationService:
    """Kênh default: chỉ ghi log, trả về 0 thiết bị."""

    def notify_report_sent(
        self,
        *,
        report_id: str,
        child_id: str,
        child_name: str,
        linked_parents: int,
    ) -> int:
        logger.info(
            "[Notification] report_id=%s child=%r linked_parents=%d "
            "-> push SKIPPED (chưa có FCM Token)",
            report_id,
            child_name,
            linked_parents,
        )
        return 0


notification_service: NotificationService = LoggingNotificationService()
