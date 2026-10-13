"""
app/models/admin_user.py
========================
ORM Model: AdminUser (Web admin - tách biệt khỏi User table)

Đây là tài khoản dành cho admin web (admin app / dev team), TÁCH BIỆT
với bảng ``users`` (chứa teacher/parent/admin của trường).

Mục đích:
- Tách quyền rõ ràng: web admin chỉ quản lý bug reports.
- Không cho nhầm lẫn với admin nhà trường (đang dùng Flutter app + users.role=admin).
- Bảo mật: web admin có password riêng, không phụ thuộc SSO hay mobile OTP.

Columns
-------
admin_user_id  : UUID PK
email          : Email đăng nhập (unique, indexed)
password_hash  : Bcrypt hash của password
full_name      : Họ tên hiển thị
is_active      : Còn hoạt động hay đã vô hiệu hóa
is_super_admin : True = super admin (full quyền), False = admin thường
last_login_at  : Lần đăng nhập gần nhất
created_at / updated_at : timestamps
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin

# ===========================================================================
# AdminUser
# ===========================================================================


class AdminUser(Base, TimestampMixin):
    """Tài khoản dành cho web admin (admin app / dev team).

    Phân biệt rõ với ``User`` (bảng chung cho teacher/parent/admin nhà trường).
    Web admin chỉ có quyền quản lý bug reports, không can thiệp vào
    dữ liệu nghiệp vụ của nhà trường.
    """

    __tablename__ = "admin_user"

    __table_args__ = (
        {"comment": "Tài khoản web admin (admin app / dev team)"},
    )

    # --- Primary key ---
    admin_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Credentials ---
    email: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
        comment="Email đăng nhập, dùng để authenticate web admin",
    )
    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Bcrypt hash của password (KHÔNG lưu plain text)",
    )

    # --- Profile ---
    full_name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
        comment="Họ và tên hiển thị trên web",
    )

    # --- Authorization ---
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        comment="Tài khoản còn hoạt động hay đã bị vô hiệu hóa",
    )
    is_super_admin: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="True = super admin (full quyền), False = admin thường",
    )

    # --- Audit ---
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Lần đăng nhập gần nhất (UTC)",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<AdminUser id={self.admin_user_id!s} "
            f"email={self.email!r} active={self.is_active}>"
        )
