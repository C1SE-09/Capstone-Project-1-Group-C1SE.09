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
    # Nhánh attendance mới cũng thêm ETA; cả hai thứ tự upgrade đều phải hợp lệ.
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TABLE leave_request ADD COLUMN IF NOT EXISTS expected_arrival_time TIME WITHOUT TIME ZONE")
    elif "expected_arrival_time" not in {column["name"] for column in sa.inspect(bind).get_columns("leave_request")}:
        op.add_column("leave_request", sa.Column("expected_arrival_time", sa.Time(), nullable=True))
    op.add_column("leave_request", sa.Column(
        "meal_warning_acknowledged", sa.Boolean(), nullable=False, server_default=sa.text("false"),
    ))


def downgrade() -> None:
    op.drop_column("leave_request", "meal_warning_acknowledged")
    # Giữ ETA dùng chung để downgrade nhánh này không làm mất dữ liệu nhánh khác.
    op.drop_column("leave_request", "request_type")
