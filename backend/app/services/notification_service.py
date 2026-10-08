"""Thông báo cho phụ huynh khi report được gửi.

Hiện tại: LoggingNotificationService - ghi log ý định gửi, ko đẩy push thật.
"""

from __future__ import annotations

import logging
import os

import firebase_admin
from firebase_admin import credentials, messaging

logger = logging.getLogger(__name__)


def get_firebase_app():
    try:
        return firebase_admin.get_app()
    except ValueError:
        credentials_path = os.getenv("FIREBASE_CREDENTIALS_PATH")

        if not credentials_path:
            raise RuntimeError(
                "FIREBASE_CREDENTIALS_PATH is not configured"
            )

        if not os.path.exists(credentials_path):
            raise RuntimeError(
                f"Firebase credentials file not found: {credentials_path}"
            )

        credential = credentials.Certificate(credentials_path)

        return firebase_admin.initialize_app(credential)


def send_push_notification(
    *,
    token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> str:
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data or {},
        token=token,
    )

    return messaging.send(
        message,
        app=get_firebase_app(),
    )


class NotificationService:
    def notify_report_sent(
        self,
        *,
        report_id: str,
        child_id: str,
        child_name: str,
        linked_parents: int,
    ) -> int:
        logger.info(
            "[Notification] report_id=%s child=%r linked_parents=%d",
            report_id,
            child_name,
            linked_parents,
        )
        return 0


notification_service = NotificationService()