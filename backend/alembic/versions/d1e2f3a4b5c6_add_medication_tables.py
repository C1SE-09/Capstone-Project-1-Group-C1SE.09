"""add medication tables

Revision ID: d1e2f3a4b5c6
Revises: 4d8e9f1a2b3c, c0b673468361
Create Date: 2026-10-28 14:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'd1e2f3a4b5c6'
down_revision: Union[str, Sequence[str], None] = ('4d8e9f1a2b3c', 'c0b673468361')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Tạo enum types nếu chưa tồn tại
    med_status_enum = postgresql.ENUM(
        'active', 'completed', 'cancelled',
        name='medication_request_status',
        create_type=False,
    )
    med_status_enum.create(op.get_bind(), checkfirst=True)

    # 2. Tạo bảng medication_request
    op.create_table(
        'medication_request',
        sa.Column('request_id', sa.UUID(), nullable=False),
        sa.Column('child_id', sa.UUID(), nullable=False, comment='Học sinh cần uống thuốc'),
        sa.Column('class_id', sa.UUID(), nullable=False, comment='Lớp học của học sinh'),
        sa.Column('parent_id', sa.UUID(), nullable=True, comment='Phụ huynh gửi lời dặn'),
        sa.Column('medication_name', sa.String(length=255), nullable=False, comment='Tên thuốc'),
        sa.Column('dosage', sa.String(length=100), nullable=False, comment='Liều lượng'),
        sa.Column('instructions', sa.Text(), nullable=True, comment='Hướng dẫn uống chi tiết'),
        sa.Column('sessions', sa.JSON(), nullable=False, server_default='[]', comment='Các buổi uống trong ngày'),
        sa.Column('start_date', sa.Date(), nullable=False, comment='Ngày bắt đầu cho uống'),
        sa.Column('end_date', sa.Date(), nullable=False, comment='Ngày kết thúc đợt thuốc'),
        sa.Column(
            'status',
            postgresql.ENUM('active', 'completed', 'cancelled', name='medication_request_status', create_type=False),
            nullable=False,
            server_default='active',
        ),
        sa.Column('notes', sa.Text(), nullable=True, comment='Ghi chú thêm từ phụ huynh'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['child_id'], ['child.child_id'], ondelete='CASCADE', name='fk_medication_request_child_id'),
        sa.ForeignKeyConstraint(['class_id'], ['class.class_id'], ondelete='CASCADE', name='fk_medication_request_class_id'),
        sa.ForeignKeyConstraint(['parent_id'], ['parent.parent_id'], ondelete='SET NULL', name='fk_medication_request_parent_id'),
        sa.PrimaryKeyConstraint('request_id'),
    )

    op.create_index('ix_medication_request_child_id', 'medication_request', ['child_id'], unique=False)
    op.create_index('ix_medication_request_class_id', 'medication_request', ['class_id'], unique=False)
    op.create_index('ix_medication_request_status', 'medication_request', ['status'], unique=False)
    op.create_index('ix_medication_request_dates', 'medication_request', ['start_date', 'end_date'], unique=False)

    # 3. Tạo bảng medication_log
    op.create_table(
        'medication_log',
        sa.Column('log_id', sa.UUID(), nullable=False),
        sa.Column('request_id', sa.UUID(), nullable=False, comment='Đơn dặn thuốc tương ứng'),
        sa.Column('log_date', sa.Date(), nullable=False, comment='Ngày cho uống thuốc'),
        sa.Column('session', sa.String(length=20), nullable=False, comment='Buổi cho uống (morning, noon, afternoon)'),
        sa.Column('is_given', sa.Boolean(), nullable=False, server_default='false', comment='Đã cho uống hay chưa'),
        sa.Column('given_by_id', sa.UUID(), nullable=True, comment='Giáo viên cho uống'),
        sa.Column('given_at', sa.DateTime(timezone=True), nullable=True, comment='Thời gian xác nhận'),
        sa.Column('notes', sa.Text(), nullable=True, comment='Ghi chú phản ứng'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['request_id'], ['medication_request.request_id'], ondelete='CASCADE', name='fk_medication_log_request_id'),
        sa.ForeignKeyConstraint(['given_by_id'], ['teacher.teacher_id'], ondelete='SET NULL', name='fk_medication_log_given_by_id'),
        sa.PrimaryKeyConstraint('log_id'),
        sa.UniqueConstraint('request_id', 'log_date', 'session', name='uq_medication_log_request_date_session'),
    )

    op.create_index('ix_medication_log_date_session', 'medication_log', ['log_date', 'session'], unique=False)
    op.create_index('ix_medication_log_given_by', 'medication_log', ['given_by_id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_medication_log_given_by', table_name='medication_log')
    op.drop_index('ix_medication_log_date_session', table_name='medication_log')
    op.drop_table('medication_log')

    op.drop_index('ix_medication_request_dates', table_name='medication_request')
    op.drop_index('ix_medication_request_status', table_name='medication_request')
    op.drop_index('ix_medication_request_class_id', table_name='medication_request')
    op.drop_index('ix_medication_request_child_id', table_name='medication_request')
    op.drop_table('medication_request')

    op.execute("DROP TYPE IF EXISTS medication_request_status")
