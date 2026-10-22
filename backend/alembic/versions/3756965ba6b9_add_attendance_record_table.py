"""add attendance_record table

Revision ID: 3756965ba6b9
Revises: b4c5d6e7f8a9
Create Date: 2026-10-20 13:00:39.442745

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '3756965ba6b9'
down_revision: Union[str, Sequence[str], None] = 'b4c5d6e7f8a9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema.
    Chỉ giữ logic tạo bảng attendance_record, loại bỏ các drift tự sinh gây mất dữ liệu.
    """
    op.create_table(
        'attendance_record',
        sa.Column('record_id', sa.UUID(), nullable=False),
        sa.Column('child_id', sa.UUID(), nullable=False),
        sa.Column('class_id', sa.UUID(), nullable=False),
        sa.Column('date', sa.Date(), nullable=False),
        sa.Column(
            'status',
            sa.Enum('present', 'absent', 'late', name='attendance_status'),
            nullable=False,
        ),
        sa.Column('check_in_time', sa.Time(), nullable=True, comment='Giờ vào lớp thực tế (dùng khi trẻ đi muộn)'),
        sa.Column('note', sa.String(length=255), nullable=True, comment='Ghi chú nhanh của cô (vd: ba mẹ xin phép trước)'),
        sa.Column('teacher_id', sa.UUID(), nullable=True, comment='Giáo viên thực hiện điểm danh (Audit log an toàn)'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['child_id'], ['child.child_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['class_id'], ['class.class_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['teacher_id'], ['teacher.teacher_id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('record_id'),
        sa.UniqueConstraint('child_id', 'date', name='uq_attendance_child_date'),
    )
    op.create_index('ix_attendance_class_date', 'attendance_record', ['class_id', 'date'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_attendance_class_date', table_name='attendance_record')
    op.drop_table('attendance_record')
    op.execute("DROP TYPE IF EXISTS attendance_status")
