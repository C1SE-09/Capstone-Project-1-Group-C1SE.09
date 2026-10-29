"""add medication_requests table

Revision ID: c7d8e9f0a1b2
Revises: 4d8e9f1a2b3c, c0b673468361
Create Date: 2026-10-29 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'c7d8e9f0a1b2'
down_revision: Union[str, Sequence[str], None] = ('4d8e9f1a2b3c', 'c0b673468361')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Tạo enum types nếu chưa tồn tại
    medication_status_enum = postgresql.ENUM(
        'pending', 'given', 'cancelled',
        name='medication_status_enum',
        create_type=False
    )
    medication_status_enum.create(op.get_bind(), checkfirst=True)

    medicine_category_enum = postgresql.ENUM(
        'prescription', 'fever_reducer', 'cough_throat', 'lozenge',
        'digestive', 'eye_nose_drops', 'other',
        name='medicine_category_enum',
        create_type=False
    )
    medicine_category_enum.create(op.get_bind(), checkfirst=True)

    # 2. Tạo bảng medication_requests
    op.create_table(
        'medication_requests',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('batch_id', sa.UUID(), nullable=False, comment='Mã đợt dặn thuốc gom nhiều cữ'),
        sa.Column('child_id', sa.UUID(), nullable=False, comment='Học sinh nhận thuốc'),
        sa.Column('parent_id', sa.UUID(), nullable=False, comment='Phụ huynh của bé'),
        sa.Column('class_id', sa.UUID(), nullable=False, comment='Lớp học của bé'),
        sa.Column('request_date', sa.Date(), nullable=False, comment='Ngày cho bé uống thuốc'),
        sa.Column('time_slot', sa.String(length=10), nullable=False, comment='Khung giờ uống thuốc'),
        sa.Column(
            'medicine_category',
            postgresql.ENUM(
                'prescription', 'fever_reducer', 'cough_throat', 'lozenge', 'digestive', 'eye_nose_drops', 'other',
                name='medicine_category_enum',
                create_type=False,
            ),
            nullable=False,
            server_default='prescription',
            comment='Phân loại thuốc / danh mục gợi ý'
        ),
        sa.Column('medicine_name', sa.String(length=255), nullable=True, comment='Tên thuốc cụ thể (tùy chọn)'),
        sa.Column('dosage', sa.String(length=255), nullable=False, comment='Liều lượng hoặc quy cách gói thuốc'),
        sa.Column('notes', sa.Text(), nullable=True, comment='Ghi chú dặn dò thêm'),
        sa.Column('prescription_image_url', sa.String(length=512), nullable=False, comment='Ảnh đơn thuốc hoặc bao bì túi thuốc'),
        sa.Column(
            'status',
            postgresql.ENUM(
                'pending', 'given', 'cancelled',
                name='medication_status_enum',
                create_type=False,
            ),
            nullable=False,
            server_default='pending',
            comment='Trạng thái cữ thuốc: pending | given | cancelled'
        ),
        sa.Column('created_by_user_id', sa.UUID(), nullable=False, comment='Tài khoản tạo đơn (Phụ huynh hoặc Giáo viên)'),
        sa.Column('created_by_role', sa.String(length=20), nullable=False, comment='Role người tạo (parent | teacher)'),
        sa.Column('given_at', sa.DateTime(timezone=True), nullable=True, comment='Thời điểm thực tế cô cho uống thuốc'),
        sa.Column('given_by_id', sa.UUID(), nullable=True, comment='Giáo viên đã xác nhận cho uống thuốc'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['child_id'], ['child.child_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['parent_id'], ['parent.parent_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['class_id'], ['class.class_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['created_by_user_id'], ['users.user_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['given_by_id'], ['teacher.teacher_id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_index('ix_medication_requests_batch_id', 'medication_requests', ['batch_id'], unique=False)
    op.create_index('ix_medication_requests_child_date', 'medication_requests', ['child_id', 'request_date'], unique=False)
    op.create_index('ix_medication_requests_class_date', 'medication_requests', ['class_id', 'request_date'], unique=False)
    op.create_index('ix_medication_requests_status', 'medication_requests', ['status'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_medication_requests_status', table_name='medication_requests')
    op.drop_index('ix_medication_requests_class_date', table_name='medication_requests')
    op.drop_index('ix_medication_requests_child_date', table_name='medication_requests')
    op.drop_index('ix_medication_requests_batch_id', table_name='medication_requests')
    op.drop_table('medication_requests')
    op.execute('DROP TYPE IF EXISTS medication_status_enum')
    op.execute('DROP TYPE IF EXISTS medicine_category_enum')
