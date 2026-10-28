"""create_health_examinations_table

Revision ID: c0b673468361
Revises: f1a2b3c4d5e7
Create Date: 2026-10-27 12:56:40.639486

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c0b673468361'
down_revision: Union[str, Sequence[str], None] = 'f1a2b3c4d5e7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'health_examinations',
        sa.Column('examination_id', sa.UUID(), nullable=False),
        sa.Column('child_id', sa.UUID(), nullable=False, comment='Học sinh được khám sức khỏe'),
        sa.Column('examination_date', sa.Date(), nullable=False, comment='Ngày thực hiện khám sức khỏe'),
        sa.Column('height', sa.Float(), nullable=False, comment='Chiều cao (cm)'),
        sa.Column('weight', sa.Float(), nullable=False, comment='Cân nặng (kg)'),
        sa.Column('bmi', sa.Float(), nullable=True, comment='Chỉ số khối cơ thể BMI (kg/m^2)'),
        sa.Column(
            'health_category',
            sa.Enum('NORMAL', 'UNDERWEIGHT', 'OVERWEIGHT', name='health_category_enum'),
            nullable=False,
            comment='Phân loại thể trạng (NORMAL / UNDERWEIGHT / OVERWEIGHT)',
        ),
        sa.Column('general_conclusion', sa.Text(), nullable=True, comment='Kết luận chung của đợt khám sức khỏe'),
        sa.Column('created_by_user_id', sa.UUID(), nullable=True, comment='User ID người nhập kết quả'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['child_id'], ['child.child_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['created_by_user_id'], ['users.user_id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('examination_id'),
    )
    op.create_index(
        'ix_health_examinations_child_date',
        'health_examinations',
        ['child_id', 'examination_date'],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_health_examinations_child_date', table_name='health_examinations')
    op.drop_table('health_examinations')
    op.execute("DROP TYPE IF EXISTS health_category_enum")
