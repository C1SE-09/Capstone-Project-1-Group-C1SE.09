"""add health_incident table

Revision ID: e2f3a4b5c6d7
Revises: d1e2f3a4b5c6
Create Date: 2026-10-28 15:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'e2f3a4b5c6d7'
down_revision: Union[str, Sequence[str], None] = 'd1e2f3a4b5c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'health_incident',
        sa.Column('incident_id', sa.UUID(), nullable=False),
        sa.Column('child_id', sa.UUID(), nullable=False, comment='Học sinh gặp sự cố'),
        sa.Column('class_id', sa.UUID(), nullable=False, comment='Lớp học của học sinh'),
        sa.Column('reported_by_id', sa.UUID(), nullable=True, comment='Giáo viên phát cảnh báo'),
        sa.Column('incident_type', sa.String(length=50), nullable=False, server_default='other', comment='Loại sự cố'),
        sa.Column('description', sa.Text(), nullable=False, comment='Mô tả tình trạng sự cố'),
        sa.Column('temperature', sa.Float(), nullable=True, comment='Nhiệt độ nếu có sốt'),
        sa.Column('action_taken', sa.Text(), nullable=True, comment='Biện pháp sơ cứu đã thực hiện'),
        sa.Column('reported_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['child_id'], ['child.child_id'], ondelete='CASCADE', name='fk_health_incident_child_id'),
        sa.ForeignKeyConstraint(['class_id'], ['class.class_id'], ondelete='CASCADE', name='fk_health_incident_class_id'),
        sa.ForeignKeyConstraint(['reported_by_id'], ['teacher.teacher_id'], ondelete='SET NULL', name='fk_health_incident_reported_by_id'),
        sa.PrimaryKeyConstraint('incident_id'),
    )

    op.create_index('ix_health_incident_child_id', 'health_incident', ['child_id'], unique=False)
    op.create_index('ix_health_incident_class_id', 'health_incident', ['class_id'], unique=False)
    op.create_index('ix_health_incident_type', 'health_incident', ['incident_type'], unique=False)
    op.create_index('ix_health_incident_reported_at', 'health_incident', ['reported_at'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_health_incident_reported_at', table_name='health_incident')
    op.drop_index('ix_health_incident_type', table_name='health_incident')
    op.drop_index('ix_health_incident_class_id', table_name='health_incident')
    op.drop_index('ix_health_incident_child_id', table_name='health_incident')
    op.drop_table('health_incident')
