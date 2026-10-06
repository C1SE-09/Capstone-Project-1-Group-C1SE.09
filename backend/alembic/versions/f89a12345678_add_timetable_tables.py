"""Add time_slot, subject, and class_schedule tables for timetable

Revision ID: f89a12345678
Revises: e5a8f2c1d904
Create Date: 2026-10-04 21:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f89a12345678"
down_revision: str | Sequence[str] | None = "e5a8f2c1d904"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Create time_slot table
    op.create_table(
        "time_slot",
        sa.Column(
            "slot_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "name",
            sa.String(length=100),
            nullable=False,
            comment="Slot display name, e.g. 7h00 - 7h30",
        ),
        sa.Column(
            "start_time",
            sa.String(length=10),
            nullable=False,
            comment="Start time (HH:MM)",
        ),
        sa.Column(
            "end_time", sa.String(length=10), nullable=False, comment="End time (HH:MM)"
        ),
        sa.Column(
            "order_index",
            sa.Integer(),
            nullable=False,
            server_default="1",
            comment="Display sort index",
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
        sa.PrimaryKeyConstraint("slot_id"),
        comment="Daily time slot definitions",
    )
    op.create_index("ix_time_slot_order", "time_slot", ["order_index"], unique=False)

    # 2. Create subject table
    op.create_table(
        "subject",
        sa.Column(
            "subject_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "name",
            sa.String(length=100),
            nullable=False,
            comment="Subject name, e.g. Tiếng Việt",
        ),
        sa.Column("code", sa.String(length=50), nullable=True, comment="Short code"),
        sa.Column(
            "color_code",
            sa.String(length=20),
            nullable=True,
            server_default="#4CAF50",
            comment="HEX color code",
        ),
        sa.Column(
            "description", sa.Text(), nullable=True, comment="Detailed description"
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
        sa.PrimaryKeyConstraint("subject_id"),
        sa.UniqueConstraint("name", name="uq_subject_name"),
        comment="Subjects and activity types for timetable",
    )
    op.create_index("ix_subject_name", "subject", ["name"], unique=False)

    # 3. Create class_schedule table
    op.create_table(
        "class_schedule",
        sa.Column(
            "schedule_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column("class_id", sa.UUID(), nullable=False, comment="Classroom entity"),
        sa.Column("subject_id", sa.UUID(), nullable=False, comment="Subject entity"),
        sa.Column("slot_id", sa.UUID(), nullable=False, comment="Time slot entity"),
        sa.Column("teacher_id", sa.UUID(), nullable=True, comment="Assigned teacher"),
        sa.Column(
            "day_of_week",
            sa.Integer(),
            nullable=False,
            comment="Day of week: 2=Mon ... 7=Sat",
        ),
        sa.Column(
            "activity_name",
            sa.String(length=255),
            nullable=True,
            comment="Headline / label",
        ),
        sa.Column("content", sa.Text(), nullable=True, comment="Detailed content"),
        sa.Column(
            "room_name",
            sa.String(length=100),
            nullable=True,
            comment="Room or physical location",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default="true",
            nullable=False,
            comment="Active flag",
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
        sa.ForeignKeyConstraint(
            ["class_id"],
            ["class.class_id"],
            name="fk_class_schedule_class_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["subject_id"],
            ["subject.subject_id"],
            name="fk_class_schedule_subject_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["slot_id"],
            ["time_slot.slot_id"],
            name="fk_class_schedule_slot_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["teacher_id"],
            ["teacher.teacher_id"],
            name="fk_class_schedule_teacher_id",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("schedule_id"),
        comment="Weekly class timetable entries",
    )
    op.create_index(
        "ix_class_schedule_class_id", "class_schedule", ["class_id"], unique=False
    )
    op.create_index(
        "ix_class_schedule_day",
        "class_schedule",
        ["class_id", "day_of_week"],
        unique=False,
    )
    op.create_index(
        "ix_class_schedule_slot", "class_schedule", ["slot_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_class_schedule_slot", table_name="class_schedule", if_exists=True)
    op.drop_index("ix_class_schedule_day", table_name="class_schedule", if_exists=True)
    op.drop_index(
        "ix_class_schedule_class_id", table_name="class_schedule", if_exists=True
    )
    op.drop_table("class_schedule")

    op.drop_index("ix_subject_name", table_name="subject", if_exists=True)
    op.drop_index("ix_subject_school_id", table_name="subject", if_exists=True)
    op.drop_table("subject")

    op.drop_index("ix_time_slot_order", table_name="time_slot", if_exists=True)
    op.drop_index("ix_time_slot_school_id", table_name="time_slot", if_exists=True)
    op.drop_table("time_slot")
