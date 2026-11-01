"""Cho phép bản ghi sổ sức khoẻ thiếu chiều cao / cân nặng / phân loại thể trạng

Revision ID: a1b2c3d4e5f7
Revises: f3d4e5f6a7b8
Create Date: 2026-10-29 22:35:00

- `height`, `weight`: NOT NULL -> NULL
- `health_category`: NOT NULL -> NULL (bỏ default NORMAL)

Lý do: cho phép nhập sổ sức khoẻ khi người dùng chỉ điền 1 trong 3 thông tin
(chiều cao, cân nặng, kết luận chung). BMI + phân loại thể trạng chỉ được
tính khi có đủ chiều cao và cân nặng.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f7"
down_revision: Union[str, Sequence[str], None] = "f3d4e5f6a7b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Cho phép height / weight / health_category = NULL."""
    op.alter_column(
        "health_examinations",
        "height",
        existing_type=sa.Float(),
        nullable=True,
    )
    op.alter_column(
        "health_examinations",
        "weight",
        existing_type=sa.Float(),
        nullable=True,
    )
    op.alter_column(
        "health_examinations",
        "health_category",
        existing_type=sa.Enum(
            "NORMAL",
            "UNDERWEIGHT",
            "OVERWEIGHT",
            name="health_category_enum",
        ),
        nullable=True,
        existing_server_default=None,
    )


def downgrade() -> None:
    """Trả về NOT NULL — bản ghi thiếu số liệu sẽ bị lỗi."""
    op.alter_column(
        "health_examinations",
        "health_category",
        existing_type=sa.Enum(
            "NORMAL",
            "UNDERWEIGHT",
            "OVERWEIGHT",
            name="health_category_enum",
        ),
        nullable=False,
        server_default="NORMAL",
    )
    op.alter_column(
        "health_examinations",
        "weight",
        existing_type=sa.Float(),
        nullable=False,
    )
    op.alter_column(
        "health_examinations",
        "height",
        existing_type=sa.Float(),
        nullable=False,
    )
