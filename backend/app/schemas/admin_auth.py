"""
app/schemas/admin_auth.py
=========================
Pydantic schemas cho Web Admin authentication.

Tách biệt với schemas/auth_schema.py (dùng cho teacher/parent của nhà trường).
"""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field

# ===========================================================================
# Request: Login
# ===========================================================================


class AdminLoginRequest(BaseModel):
    """Payload cho ``POST /api/admin-auth/login``."""

    email: EmailStr = Field(
        ...,
        description="Email đăng nhập",
        examples=["admin@kinderlog.dev"],
    )
    password: str = Field(
        ...,
        min_length=6,
        max_length=200,
        description="Mật khẩu (tối thiểu 6 ký tự)",
    )


# ===========================================================================
# Response: Login
# ===========================================================================


class AdminLoginResponse(BaseModel):
    """Response khi đăng nhập thành công."""

    access_token: str = Field(..., description="JWT access token")
    token_type: str = Field(default="bearer", description="Loại token")
    admin: AdminUserOut = Field(..., description="Thông tin admin")


# ===========================================================================
# Response: Admin profile
# ===========================================================================


class AdminUserOut(BaseModel):
    """Thông tin admin user (ẩn password_hash)."""

    admin_user_id: uuid.UUID = Field(..., description="UUID của admin")
    email: str = Field(..., description="Email")
    full_name: str = Field(..., description="Họ tên")
    is_active: bool = Field(..., description="Còn hoạt động không")
    is_super_admin: bool = Field(..., description="Là super admin không")
    last_login_at: datetime | None = Field(None, description="Lần đăng nhập gần nhất")
    created_at: datetime = Field(..., description="Ngày tạo")

    model_config = ConfigDict(from_attributes=True)


# Resolve forward reference
AdminLoginResponse.model_rebuild()
