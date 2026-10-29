"""rename health exam comments to health record book

Revision ID: b7c8d9e0f1a2
Revises: ae06abd00007
Create Date: 2026-10-28 13:25:00.000000

Đổi thuật ngữ "khám sức khỏe" -> "sổ sức khoẻ" cho comment của bảng
health_examinations (chỉ metadata, không đổi cấu trúc cột/dữ liệu).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'b7c8d9e0f1a2'
down_revision: Union[str, Sequence[str], None] = 'ae06abd00007'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.alter_column(
        'health_examinations',
        'child_id',
        existing_type=sa.UUID(),
        comment='Học sinh có số liệu ghi nhận',
    )
    op.alter_column(
        'health_examinations',
        'examination_date',
        existing_type=sa.Date(),
        comment='Ngày ghi nhận số liệu',
    )
    op.alter_column(
        'health_examinations',
        'general_conclusion',
        existing_type=sa.Text(),
        comment='Kết luận chung của đợt ghi nhận',
    )
    op.alter_column(
        'health_examinations',
        'created_by_user_id',
        existing_type=sa.UUID(),
        comment='Tài khoản thực hiện ghi nhận',
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.alter_column(
        'health_examinations',
        'child_id',
        existing_type=sa.UUID(),
        comment='Học sinh được khám sức khỏe',
    )
    op.alter_column(
        'health_examinations',
        'examination_date',
        existing_type=sa.Date(),
        comment='Ngày thực hiện khám sức khỏe',
    )
    op.alter_column(
        'health_examinations',
        'general_conclusion',
        existing_type=sa.Text(),
        comment='Kết luận chung của đợt khám sức khỏe',
    )
    op.alter_column(
        'health_examinations',
        'created_by_user_id',
        existing_type=sa.UUID(),
        comment='User ID người nhập kết quả',
    )
