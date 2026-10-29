"""Thêm phân loại theo UI, mở rộng liều lượng, giữ toàn bộ đơn/log thuốc cũ."""

import sqlalchemy as sa
from alembic import op

revision = "f2c3d4e5f6a7"
down_revision = "f1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TYPE medicine_category_enum ADD VALUE IF NOT EXISTS 'non_prescription'")
        op.execute("ALTER TYPE medicine_category_enum ADD VALUE IF NOT EXISTS 'supplement'")
        op.alter_column("medication_request", "dosage", existing_type=sa.String(100), type_=sa.String(255))
    else:
        with op.batch_alter_table("medication_request") as batch:
            batch.alter_column("dosage", existing_type=sa.String(100), type_=sa.String(255))


def downgrade() -> None:
    # Không thu nhỏ cột hay xóa enum đã ghi: rollback code phải giữ dữ liệu y tế.
    op.execute("SELECT 1")
