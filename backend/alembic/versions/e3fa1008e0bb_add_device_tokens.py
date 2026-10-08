"""add device tokens

Revision ID: e3fa1008e0bb
Revises: f89a12345678
Create Date: 2026-10-08 04:11:18.117718

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "e3fa1008e0bb"
down_revision: str | Sequence[str] | None = "f89a12345678"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "device_tokens",
        sa.Column("device_token_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("device_type", sa.String(length=20), nullable=True),
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
            ["user_id"],
            ["users.user_id"],
            name="fk_device_tokens_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("device_token_id"),
        sa.UniqueConstraint(
            "user_id",
            "token",
            name="uq_user_device_token",
        ),
    )

    op.create_index(
        "ix_device_tokens_user_id",
        "device_tokens",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_device_tokens_user_id",
        table_name="device_tokens",
    )
    op.drop_table("device_tokens")