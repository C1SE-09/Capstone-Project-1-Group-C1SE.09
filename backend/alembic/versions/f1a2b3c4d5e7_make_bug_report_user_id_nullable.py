"""make bug_report user_id nullable

Revision ID: f1a2b3c4d5e7
Revises: e4d7e8acd61d
Create Date: 2026-10-22 23:22:00.000000

"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "f1a2b3c4d5e7"
down_revision = "e4d7e8acd61d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "bug_report",
        "user_id",
        existing_type=sa.UUID(),
        nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "bug_report",
        "user_id",
        existing_type=sa.UUID(),
        nullable=False,
    )
