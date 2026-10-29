"""Hợp nhất head dặn thuốc, mở rộng đúng bảng ORM dùng mà không xóa dữ liệu."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "f1b2c3d4e5f6"
down_revision = ("f0a1b2c3d4e5", "c7d8e9f0a1b2")
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TYPE medication_request_status ADD VALUE IF NOT EXISTS 'pending'")
        op.execute("ALTER TYPE medication_request_status ADD VALUE IF NOT EXISTS 'given'")

    columns = set() if op.get_context().as_sql else {
        column["name"] for column in sa.inspect(bind).get_columns("medication_request")
    }
    # Hai API đều dùng medication_request; bảng plural của nhánh c7 được giữ nguyên.
    additions = [
        sa.Column("batch_id", sa.UUID(), nullable=True),
        sa.Column("time_slot", sa.String(10), nullable=True),
        sa.Column("request_date", sa.Date(), nullable=True),
        sa.Column("medicine_category", postgresql.ENUM(
            "prescription", "fever_reducer", "cough_throat", "lozenge", "digestive", "eye_nose_drops", "other",
            name="medicine_category_enum", create_type=False,
        ), nullable=True),
        sa.Column("prescription_image_url", sa.String(512), nullable=True),
        sa.Column("created_by_user_id", sa.UUID(), nullable=True),
        sa.Column("created_by_role", sa.String(20), nullable=True),
        sa.Column("given_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("given_by_id", sa.UUID(), nullable=True),
    ]
    for column in additions:
        if column.name not in columns:
            op.add_column("medication_request", column)

    if bind.dialect.name == "postgresql":
        if "created_by_user_id" not in columns:
            op.create_foreign_key("fk_medication_request_creator", "medication_request", "users",
                                  ["created_by_user_id"], ["user_id"], ondelete="SET NULL")
        if "given_by_id" not in columns:
            op.create_foreign_key("fk_medication_request_given_teacher", "medication_request", "teacher",
                                  ["given_by_id"], ["teacher_id"], ondelete="SET NULL")


def downgrade() -> None:
    # Expand-only: rollback code không được làm mất lịch sử cữ thuốc/giáo viên.
    op.execute("SELECT 1")
