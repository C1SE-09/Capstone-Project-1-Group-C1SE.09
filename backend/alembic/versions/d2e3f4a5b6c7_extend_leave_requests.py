"""Bổ sung loại đơn/ETA/xác nhận tiền ăn và hợp nhất hai head hiện có.

Revision ID: d2e3f4a5b6c7
Revises: 4d8e9f1a2b3c, c0b673468361
Create Date: 2026-10-28
"""

import sqlalchemy as sa
from alembic import op

revision = "d2e3f4a5b6c7"
down_revision = ("4d8e9f1a2b3c", "c0b673468361")
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("leave_request", sa.Column(
        "request_type", sa.String(16), nullable=False, server_default="absence",
    ))
    op.add_column("leave_request", sa.Column("expected_arrival_time", sa.Time(), nullable=True))
    op.add_column("leave_request", sa.Column(
        "meal_warning_acknowledged", sa.Boolean(), nullable=False, server_default=sa.text("false"),
    ))


def downgrade() -> None:
    op.drop_column("leave_request", "meal_warning_acknowledged")
    op.drop_column("leave_request", "expected_arrival_time")
    op.drop_column("leave_request", "request_type")
