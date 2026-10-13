"""
app/api/endpoints/admin_auth.py
===============================
REST API endpoints cho Web Admin authentication.

3 endpoints:
    POST   /api/admin-auth/login    Login bằng email + password
    GET    /api/admin-auth/me       Lấy thông tin admin hiện tại
    POST   /api/admin-auth/logout   Logout (client-side xóa token, server chỉ log)

Authentication: Bearer JWT
"""

from __future__ import annotations

import logging

from app.core.admin_security import get_current_admin
from app.core.database import get_db
from app.models.admin_user import AdminUser
from app.schemas.admin_auth import (
    AdminLoginRequest,
    AdminLoginResponse,
    AdminUserOut,
)
from app.services.admin_auth_service import (
    AdminAuthError,
    authenticate_admin,
    create_admin_access_token,
)
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin-auth", tags=["admin-auth"])


@router.post(
    "/login",
    response_model=AdminLoginResponse,
    summary="Web Admin Login",
    description=(
        "Đăng nhập bằng email + password để lấy JWT access token. "
        "Token dùng để gọi các API admin (quản lý bug reports, ...)."
    ),
)
def admin_login(
    payload: AdminLoginRequest,
    db: Session = Depends(get_db),
) -> AdminLoginResponse:
    try:
        admin = authenticate_admin(
            db=db,
            email=payload.email,
            password=payload.password,
        )
    except AdminAuthError as exc:
        raise HTTPException(
            status_code=exc.status_code,
            detail=exc.message,
        ) from exc

    token = create_admin_access_token(admin.admin_user_id)
    return AdminLoginResponse(
        access_token=token,
        token_type="bearer",
        admin=AdminUserOut.model_validate(admin),
    )


@router.get(
    "/me",
    response_model=AdminUserOut,
    summary="Get current admin info",
    description="Lấy thông tin admin đang đăng nhập (dựa trên JWT token).",
)
def get_me(
    current_admin: AdminUser = Depends(get_current_admin),
) -> AdminUserOut:
    return AdminUserOut.model_validate(current_admin)


@router.post(
    "/logout",
    summary="Logout (client-side only)",
    description=(
        "Logout thực chất chỉ là client xóa token. Endpoint này tồn tại "
        "để client có thể log ra ngoài server và để Swagger docs đầy đủ."
    ),
)
def admin_logout(
    current_admin: AdminUser = Depends(get_current_admin),
) -> dict[str, str]:
    logger.info("[admin-auth] Admin logged out: %s", current_admin.email)
    return {"message": "Đã đăng xuất. Hãy xóa token ở phía client."}
