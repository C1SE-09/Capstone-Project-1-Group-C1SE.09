"""add unified user table and remove firebase_uid

Revision ID: e5a8f2c1d904
Revises: 1d221a9914e8
Create Date: 2026-09-30 21:40:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e5a8f2c1d904"
down_revision: str | Sequence[str] | None = "1d221a9914e8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Create users table
    op.create_table(
        "users",
        sa.Column(
            "user_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "username",
            sa.String(length=50),
            nullable=False,
            comment="Login username, e.g. teacher_mai or parent_tuan",
        ),
        sa.Column(
            "password_hash",
            sa.String(length=255),
            nullable=False,
            comment="Bcrypt password hash",
        ),
        sa.Column(
            "role",
            sa.Enum("teacher", "parent", "admin", name="user_role_enum"),
            nullable=False,
            comment="Account role – teacher | parent | admin",
        ),
        sa.Column(
            "teacher_id",
            sa.UUID(),
            nullable=True,
            comment="Linked teacher entity (NULL if not a teacher)",
        ),
        sa.Column(
            "parent_id",
            sa.UUID(),
            nullable=True,
            comment="Linked parent entity (NULL if not a parent)",
        ),
        sa.Column(
            "status",
            sa.Enum("active", "inactive", "suspended", name="user_status_enum"),
            server_default="active",
            nullable=False,
            comment="Account lifecycle status",
        ),
        sa.Column(
            "is_verified",
            sa.Boolean(),
            server_default="true",
            nullable=False,
            comment="True after account verification",
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
        sa.ForeignKeyConstraint(
            ["teacher_id"],
            ["teacher.teacher_id"],
            name="fk_users_teacher_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["parent_id"],
            ["parent.parent_id"],
            name="fk_users_parent_id",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id"),
        sa.UniqueConstraint("username", name="uq_users_username"),
        comment="User accounts for authentication in ADARK",
    )
    op.create_index("ix_users_username", "users", ["username"], unique=False)
    op.create_index("ix_users_role", "users", ["role"], unique=False)
    op.create_index("ix_users_teacher_id", "users", ["teacher_id"], unique=False)
    op.create_index("ix_users_parent_id", "users", ["parent_id"], unique=False)

    # 2. Drop firebase_uid from teacher and parent tables if existing
    try:
        op.drop_constraint("uq_teacher_firebase_uid", "teacher", type_="unique")
    except Exception:
        pass
    try:
        op.drop_column("teacher", "firebase_uid")
    except Exception:
        pass

    try:
        op.drop_constraint("uq_parent_firebase_uid", "parent", type_="unique")
    except Exception:
        pass
    try:
        op.drop_column("parent", "firebase_uid")
    except Exception:
        pass


def downgrade() -> None:
    op.add_column(
        "parent",
        sa.Column("firebase_uid", sa.String(length=128), nullable=True),
    )
    op.create_unique_constraint("uq_parent_firebase_uid", "parent", ["firebase_uid"])

    op.add_column(
        "teacher",
        sa.Column("firebase_uid", sa.String(length=128), nullable=True),
    )
    op.create_unique_constraint("uq_teacher_firebase_uid", "teacher", ["firebase_uid"])

    op.drop_index("ix_users_parent_id", table_name="users")
    op.drop_index("ix_users_teacher_id", table_name="users")
    op.drop_index("ix_users_role", table_name="users")
    op.drop_index("ix_users_username", table_name="users")
    op.drop_table("users")

    op.execute("DROP TYPE IF EXISTS user_role_enum")
    op.execute("DROP TYPE IF EXISTS user_status_enum")
