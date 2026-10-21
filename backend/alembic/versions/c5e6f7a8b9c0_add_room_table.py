"""create room table for school locations and facilities

Revision ID: c5e6f7a8b9c0
Revises: b4c5d6e7f8a9
Create Date: 2026-10-21 21:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "c5e6f7a8b9c0"
down_revision: Union[str, Sequence[str], None] = "b4c5d6e7f8a9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "room",
        sa.Column(
            "room_id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
            comment="Surrogate primary key",
        ),
        sa.Column(
            "school_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("school.school_id", ondelete="CASCADE", name="fk_room_school_id"),
            nullable=False,
            comment="Foreign key to school table",
        ),
        sa.Column(
            "class_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("class.class_id", ondelete="SET NULL", name="fk_room_class_id"),
            nullable=True,
            comment="Foreign key to class table if dedicated classroom",
        ),
        sa.Column(
            "name",
            sa.String(length=100),
            nullable=False,
            comment="Tên phòng hoặc địa điểm (vd: Phòng học Mầm A, Sân cỏ...)",
        ),
        sa.Column(
            "room_type",
            sa.String(length=50),
            server_default="CLASSROOM",
            nullable=False,
            comment="Loại phòng: CLASSROOM, FUNCTIONAL, OUTDOOR, COMMON",
        ),
        sa.Column(
            "capacity",
            sa.Integer(),
            server_default="30",
            nullable=True,
            comment="Sức chứa tối đa",
        ),
        sa.Column(
            "is_shared",
            sa.Boolean(),
            server_default="false",
            nullable=False,
            comment="True nếu là khu vực dùng chung cho nhiều lớp (vd: Sân cỏ, Sân trường)",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default="true",
            nullable=False,
            comment="Trạng thái hoạt động",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_room_school_id", "room", ["school_id"], unique=False)
    op.create_index("ix_room_class_id", "room", ["class_id"], unique=False)
    op.create_index("ix_room_type", "room", ["room_type"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_room_type", table_name="room")
    op.drop_index("ix_room_class_id", table_name="room")
    op.drop_index("ix_room_school_id", table_name="room")
    op.drop_table("room")
