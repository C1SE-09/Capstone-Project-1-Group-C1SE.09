"""
app/core/admin_security.py
==========================
Authentication & Authorization cho Web Admin (tách biệt với User auth).

Sử dụng:
    from app.core.admin_security import get_current_admin, require_admin

    @router.get("/api/bug-reports")
    def list_bug_reports(admin: AdminUser = Depends(get_current_admin)):
        ...
"""

from __future__ import annotations

import logging
import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import ALGORITHM, SECRET_KEY
from app.models.admin_user import AdminUser
from app.services.admin_auth_service import get_admin_by_id

logger = logging.getLogger(__name__)

# tokenUrl này CHỈ để FastAPI OpenAPI docs biết nơi login
oauth2_scheme_admin = OAuth2PasswordBearer(
    tokenUrl="/api/admin-auth/login",
    auto_error=False,
)


def get_current_admin(
    token: str | None = Depends(oauth2_scheme_admin),
    db: Session = Depends(get_db),
) -> AdminUser:
    """Dependency: lấy admin user từ JWT token.

    Raises:
        HTTPException 401: nếu token không hợp lệ hoặc admin không tồn tại.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Không thể xác thực thông tin đăng nhập",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not token:
        raise credentials_exception

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        admin_id_str: str | None = payload.get("sub")
        role: str | None = payload.get("role")
        if admin_id_str is None or role != "admin_app":
            raise credentials_exception
        admin_id = uuid.UUID(str(admin_id_str))
    except (JWTError, ValueError) as exc:
        logger.warning("[admin-auth] Token decode failed: %s", exc)
        raise credentials_exception from exc

    admin = get_admin_by_id(db, admin_id)
    if admin is None or not admin.is_active:
        raise credentials_exception

    return admin


def require_admin(current_admin: AdminUser = Depends(get_current_admin)) -> AdminUser:
    """Dependency: yêu cầu admin (super hoặc thường)."""
    if not current_admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản admin đã bị vô hiệu hóa",
        )
    return current_admin


def require_super_admin(
    current_admin: AdminUser = Depends(get_current_admin),
) -> AdminUser:
    """Dependency: chỉ super admin mới được phép."""
    if not current_admin.is_super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ super admin mới có quyền thực hiện thao tác này",
        )
    return current_admin
