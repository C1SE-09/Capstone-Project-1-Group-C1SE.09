"""add excused_absent and leave sync

Revision ID: a2b3c4d5e6f7
Revises: 7b6aa28fd576
Create Date: 2026-10-28 17:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'a2b3c4d5e6f7'
down_revision: Union[str, Sequence[str], None] = 'e2f3a4b5c6d7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Thêm giá trị 'excused_absent' vào enum attendance_status
    op.execute("ALTER TYPE attendance_status ADD VALUE IF NOT EXISTS 'excused_absent'")

    # 2. Thêm giá trị 'cancelled' vào enum leave_request_status
    op.execute("ALTER TYPE leave_request_status ADD VALUE IF NOT EXISTS 'cancelled'")

    # 3. Tạo enum leave_type nếu chưa tồn tại
    leave_type_enum = postgresql.ENUM('single_day', 'multi_day', 'late', name='leave_type', create_type=False)
    leave_type_enum.create(op.get_bind(), checkfirst=True)

    # 4. Thêm cột expected_arrival_time vào bảng attendance_record
    op.add_column(
        'attendance_record',
        sa.Column(
            'expected_arrival_time',
            sa.Time(),
            nullable=True,
            comment='Giờ dự kiến đến lớp (dùng khi trẻ báo đi muộn/ETA)',
        )
    )

    # 5. Bổ sung các cột còn thiếu cho bảng leave_request (nếu chưa có)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'leave_request' AND column_name = 'type'
            ) THEN
                ALTER TABLE leave_request ADD COLUMN type leave_type NOT NULL DEFAULT 'single_day';
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'leave_request' AND column_name = 'expected_arrival_time'
            ) THEN
                ALTER TABLE leave_request ADD COLUMN expected_arrival_time TIME NULL;
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'leave_request' AND column_name = 'contact_phone'
            ) THEN
                ALTER TABLE leave_request ADD COLUMN contact_phone VARCHAR(20) NULL;
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'leave_request' AND column_name = 'submitted_after_cutoff'
            ) THEN
                ALTER TABLE leave_request ADD COLUMN submitted_after_cutoff BOOLEAN NOT NULL DEFAULT FALSE;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    # Xoá các cột bổ sung
    op.drop_column('attendance_record', 'expected_arrival_time')
    op.execute("""
        ALTER TABLE leave_request DROP COLUMN IF EXISTS submitted_after_cutoff;
        ALTER TABLE leave_request DROP COLUMN IF EXISTS contact_phone;
        ALTER TABLE leave_request DROP COLUMN IF EXISTS expected_arrival_time;
        ALTER TABLE leave_request DROP COLUMN IF EXISTS type;
    """)
