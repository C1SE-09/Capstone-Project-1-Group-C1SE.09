"""add parent relationship

Revision ID: ed2f8a1c582f
Revises: 81d26c5cb36d
Create Date: 2026-10-14 15:11:59.331513

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'ed2f8a1c582f'
down_revision: Union[str, Sequence[str], None] = '81d26c5cb36d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.

    Chỉ giữ thay đổi của task: autogenerate còn detect drift cũ
    (drop teacher_class, drop uq_admin_user_email, đổi comment hàng loạt)
    — áp dụng sẽ mất dữ liệu nên đã lược bỏ.
    """
    op.add_column(
        'parent',
        sa.Column(
            'relationship',
            sa.String(length=20),
            nullable=True,
            comment='Quan hệ với bé (vd: Bố, Mẹ) do phụ huynh tự khai',
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('parent', 'relationship')
