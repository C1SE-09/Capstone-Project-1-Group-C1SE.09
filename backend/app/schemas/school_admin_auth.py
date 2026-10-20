"""
app/schemas/school_admin_auth.py
================================
Pydantic schemas cho School Admin Web login.

School Admin = tài khoản thuộc bảng ``users`` với ``role=admin``.
Đây là admin của trường (school), khác với web admin (AdminUser table)
chỉ dùng cho dev team quản lý bug reports.
"""

from __future__ import annotations


from pydantic import BaseModel, Field


# ===========================================================================
# Request: Login
# ===========================================================================


class SchoolAdminLoginRequest(BaseModel):
    """Payload cho ``POST /api/school-admin/login``.

    Chấp nhận username, email hoặc số điện thoại (giống auth flow thường).
    """

    username: str = Field(
        ...,
        description="Tên đăng nhập / Gmail / Số điện thoại",
        examples=["admin_truong", "admin.truong@gmail.com"],
    )
    password: str = Field(
        ...,
        min_length=6,
        max_length=200,
        description="Mật khẩu (tối thiểu 6 ký tự)",
    )
    device_id: str | None = Field(None, description="ID thiết bị")
    device_name: str | None = Field(None, description="Tên thiết bị hiển thị")


# ===========================================================================
# Response: Login
# ===========================================================================


class SchoolAdminLoginResponse(BaseModel):
    """Response khi đăng nhập thành công."""

    access_token: str = Field(..., description="JWT access token")
    refresh_token: str = Field(..., description="JWT refresh token")
    session_id: str = Field(..., description="Session ID")
    token_type: str = Field(default="bearer", description="Loại token")
    role: str = Field(default="admin", description="Role - luôn là admin")
    user_id: str = Field(..., description="UUID của user")
    username: str = Field(..., description="Tên đăng nhập")
    full_name: str = Field(..., description="Họ tên hiển thị (lấy từ username nếu không có)")
    school_id: str | None = Field(None, description="ID trường (nếu có)")
    school_name: str | None = Field(None, description="Tên trường (nếu có)")