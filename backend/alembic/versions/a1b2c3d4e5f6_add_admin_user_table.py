"""add admin_user table for web admin

Revision ID: a1b2c3d4e5f6
Revises: c1c17a05262a
Create Date: 2026-10-13 21:50:00.000000

NOTE
----
Tạo bảng ``admin_user`` tách biệt với ``users`` để dành riêng cho
web admin (admin app / dev team). Web admin chỉ có quyền quản lý
bug reports, không can thiệp vào dữ liệu nghiệp vụ trường học.
"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: str | Sequence[str] | None = "c1c17a05262a"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema - add admin_user table."""
    op.create_table(
        "admin_user",
        sa.Column(
            "admin_user_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "email",
            sa.String(length=255),
            nullable=False,
            comment="Email đăng nhập, dùng để authenticate web admin",
        ),
        sa.Column(
            "password_hash",
            sa.String(length=255),
            nullable=False,
            comment="Bcrypt hash của password (KHÔNG lưu plain text)",
        ),
        sa.Column(
            "full_name",
            sa.String(length=200),
            nullable=False,
            comment="Họ và tên hiển thị trên web",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
            comment="Tài khoản còn hoạt động hay đã bị vô hiệu hóa",
        ),
        sa.Column(
            "is_super_admin",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="True = super admin (full quyền), False = admin thường",
        ),
        sa.Column(
            "last_login_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Lần đăng nhập gần nhất (UTC)",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("admin_user_id"),
        sa.UniqueConstraint("email", name="uq_admin_user_email"),
        comment="Tài khoản web admin (admin app / dev team)",
    )
    op.create_index("ix_admin_user_email", "admin_user", ["email"], unique=True)


def downgrade() -> None:
    """Downgrade schema - drop admin_user table."""
    op.drop_index("ix_admin_user_email", table_name="admin_user")
    op.drop_table("admin_user")
