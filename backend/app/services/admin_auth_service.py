"""
app/services/admin_auth_service.py
==================================
Service layer cho Web Admin authentication.

Tác vụ:
- authenticate_admin: verify email + password, tạo JWT
- create_admin_access_token: tạo JWT cho admin (role="admin_app")
- get_admin_by_id: lấy thông tin admin từ token

NOTE: Admin web được phân biệt với User (role=admin) của nhà trường
bằng role claim trong JWT: ``role = "admin_app"``.
"""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from app.core.security import (
    ALGORITHM,
    SECRET_KEY,
    hash_password,
    verify_password,
)
from app.models.admin_user import AdminUser
from jose import jwt
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


# ===========================================================================
# Constants
# ===========================================================================

ACCESS_TOKEN_EXPIRE_MINUTES = 480  # 8 tiếng (admin web thường ngồi lâu)


# ===========================================================================
# Errors
# ===========================================================================


class AdminAuthError(Exception):
    """Base exception cho admin auth."""

    def __init__(self, message: str, status_code: int = 401) -> None:
        self.message = message
        self.status_code = status_code
        super().__init__(message)


# ===========================================================================
# Token helpers
# ===========================================================================


def create_admin_access_token(admin_user_id: uuid.UUID) -> str:
    """Tạo JWT cho admin web.

    JWT payload:
        sub   : admin_user_id (string)
        role  : "admin_app"  (phân biệt với "admin" của nhà trường)
        exp   : expiry timestamp
        iat   : issued at
    """
    now = datetime.now(UTC)
    expire = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload: dict[str, Any] = {
        "sub": str(admin_user_id),
        "role": "admin_app",
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


# ===========================================================================
# Authentication
# ===========================================================================


def authenticate_admin(db: Session, email: str, password: str) -> AdminUser:
    """Xác thực admin bằng email + password.

    Args:
        db      : SQLAlchemy session
        email   : Email đăng nhập
        password: Plain text password

    Returns:
        AdminUser instance nếu thành công.

    Raises:
        AdminAuthError: nếu email/password sai hoặc tài khoản bị vô hiệu.
    """
    email_normalized = email.strip().lower()
    admin = db.query(AdminUser).filter(AdminUser.email == email_normalized).first()

    if admin is None:
        logger.warning("[admin-auth] Login failed: email not found: %s", email_normalized)
        raise AdminAuthError("Email hoặc mật khẩu không đúng", status_code=401)

    if not admin.is_active:
        logger.warning(
            "[admin-auth] Login failed: account disabled: %s", email_normalized
        )
        raise AdminAuthError("Tài khoản đã bị vô hiệu hóa", status_code=403)

    if not verify_password(password, admin.password_hash):
        logger.warning(
            "[admin-auth] Login failed: wrong password for %s", email_normalized
        )
        raise AdminAuthError("Email hoặc mật khẩu không đúng", status_code=401)

    # Cập nhật last_login_at
    admin.last_login_at = datetime.now(UTC)
    db.commit()
    db.refresh(admin)

    logger.info("[admin-auth] Login OK: %s (super=%s)", email_normalized, admin.is_super_admin)
    return admin


def get_admin_by_id(db: Session, admin_user_id: uuid.UUID) -> AdminUser | None:
    """Lấy admin theo ID. Trả về None nếu không tồn tại."""
    return db.query(AdminUser).filter(AdminUser.admin_user_id == admin_user_id).first()


# ===========================================================================
# Seed helper
# ===========================================================================


def create_admin_user(
    db: Session,
    email: str,
    password: str,
    full_name: str,
    is_super_admin: bool = False,
) -> AdminUser:
    """Tạo admin user mới. Dùng cho CLI seed script.

    Args:
        db             : SQLAlchemy session
        email          : Email (sẽ được normalize về lowercase)
        password       : Plain text password (sẽ được hash)
        full_name      : Họ tên
        is_super_admin : Có phải super admin không

    Returns:
        AdminUser instance vừa tạo.
    """
    email_normalized = email.strip().lower()
    existing = db.query(AdminUser).filter(AdminUser.email == email_normalized).first()
    if existing is not None:
        raise AdminAuthError(f"Email đã tồn tại: {email_normalized}", status_code=409)

    admin = AdminUser(
        admin_user_id=uuid.uuid4(),
        email=email_normalized,
        password_hash=hash_password(password),
        full_name=full_name.strip(),
        is_active=True,
        is_super_admin=is_super_admin,
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    logger.info("[admin-auth] Created admin user: %s", email_normalized)
    return admin
