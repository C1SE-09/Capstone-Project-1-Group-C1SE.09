"""Tiện ích push notification qua Firebase Cloud Messaging (FCM).

- ``get_firebase_app``: khởi tạo Firebase app từ service account JSON.
- ``send_push_notification``: gửi 1 message tới 1 device token.
- ``is_invalid_token``: nhận diện token không còn hợp lệ (để xoá khỏi DB).
- ``parent_device_tokens``: device token của hộ gia đình phụ huynh của trẻ.
"""

from __future__ import annotations

import logging
import os
import uuid

import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy.orm import Session

from app.config import settings
from app.models.device_token import DeviceToken
from app.models.user import User

logger = logging.getLogger(__name__)

# FCM ném các lỗi này khi token bị gỡ app / đổi thiết bị / sai sender.
_INVALID_TOKEN_ERROR_NAMES = {"UnregisteredError", "SenderIdMismatchError"}
# Chuỗi nhận diện token rác trong InvalidArgumentError — chỉ xoá token khi lỗi
# thực sự nói về registration token, tránh xoá nhầm khi lỗi đến từ message.
_REGISTRATION_TOKEN_ERROR_HINT = "registration token"


def get_firebase_app():
    """Trả về Firebase app đang dùng, khởi tạo lần đầu từ service account."""
    try:
        return firebase_admin.get_app()
    except ValueError:
        credentials_path = settings.firebase_credentials_path or os.getenv(
            "FIREBASE_CREDENTIALS_PATH", ""
        )

        if not credentials_path:
            raise RuntimeError("FIREBASE_CREDENTIALS_PATH is not configured")

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


def is_invalid_token(error: Exception) -> bool:
    """True khi FCM báo token không còn dùng được (nên xoá khỏi DB)."""
    name = error.__class__.__name__
    if name in _INVALID_TOKEN_ERROR_NAMES:
        return True
    return (
        name == "InvalidArgumentError"
        and _REGISTRATION_TOKEN_ERROR_HINT in str(error).lower()
    )


def parent_device_tokens(db: Session, parent_id: uuid.UUID) -> list[DeviceToken]:
    """Toàn bộ device token của các tài khoản phụ huynh thuộc hộ gia đình."""
    return (
        db.query(DeviceToken)
        .join(User, DeviceToken.user_id == User.user_id)
        .filter(User.parent_id == parent_id)
        .all()
    )
