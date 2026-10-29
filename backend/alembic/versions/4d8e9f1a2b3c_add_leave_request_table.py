"""add leave_request table

Revision ID: 4d8e9f1a2b3c
Revises: f1a2b3c4d5e7
Create Date: 2026-10-26 19:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '4d8e9f1a2b3c'
down_revision: Union[str, Sequence[str], None] = 'f1a2b3c4d5e7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Tạo enum type
    leave_status_enum = postgresql.ENUM('pending', 'approved', 'rejected', name='leave_request_status', create_type=False)
    leave_status_enum.create(op.get_bind(), checkfirst=True)

    # 2. Tạo bảng leave_request
    op.create_table(
        'leave_request',
        sa.Column('request_id', sa.UUID(), nullable=False),
        sa.Column('child_id', sa.UUID(), nullable=False),
        sa.Column('parent_id', sa.UUID(), nullable=False),
        sa.Column('class_id', sa.UUID(), nullable=False),
        sa.Column('from_date', sa.Date(), nullable=False, comment='Ngày bắt đầu nghỉ'),
        sa.Column('to_date', sa.Date(), nullable=False, comment='Ngày kết thúc nghỉ'),
        sa.Column('reason', sa.Text(), nullable=False, comment='Lý do xin nghỉ của phụ huynh'),
        sa.Column('attachment_url', sa.String(length=500), nullable=True, comment='Ảnh đính kèm đơn thuốc/giấy khám'),
        sa.Column(
            'status',
            leave_status_enum,
            nullable=False,
            server_default='pending',
        ),
        sa.Column('reject_reason', sa.Text(), nullable=True, comment='Lý do từ chối nếu reject'),
        sa.Column('reviewed_by', sa.UUID(), nullable=True, comment='Giáo viên duyệt đơn'),
        sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True, comment='Thời điểm duyệt/từ chối'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['child_id'], ['child.child_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['parent_id'], ['parent.parent_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['class_id'], ['class.class_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['reviewed_by'], ['teacher.teacher_id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('request_id'),
    )

    op.create_index('ix_leave_request_class_status', 'leave_request', ['class_id', 'status'], unique=False)
    op.create_index('ix_leave_request_child_dates', 'leave_request', ['child_id', 'from_date', 'to_date'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_leave_request_child_dates', table_name='leave_request')
    op.drop_index('ix_leave_request_class_status', table_name='leave_request')
    op.drop_table('leave_request')
    op.execute("DROP TYPE IF EXISTS leave_request_status")
