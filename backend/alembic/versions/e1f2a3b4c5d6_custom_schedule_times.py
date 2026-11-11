"""Allow custom schedule times without creating time_slot rows and clean up unused custom slots

Revision ID: e1f2a3b4c5d6
Revises: d9f0a1b2c3d4
Create Date: 2026-11-11 20:50:00.000000

"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "e1f2a3b4c5d6"
down_revision: str | Sequence[str] | None = "d9f0a1b2c3d4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "class_schedule",
        sa.Column(
            "custom_start_time",
            sa.String(length=10),
            nullable=True,
            comment="Custom start time (HH:MM) when not linked to a time_slot",
        ),
    )
    op.add_column(
        "class_schedule",
        sa.Column(
            "custom_end_time",
            sa.String(length=10),
            nullable=True,
            comment="Custom end time (HH:MM) when not linked to a time_slot",
        ),
    )
    op.alter_column(
        "class_schedule",
        "slot_id",
        existing_type=sa.UUID(),
        nullable=True,
    )
    op.drop_constraint(
        "fk_class_schedule_slot_id",
        "class_schedule",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "fk_class_schedule_slot_id",
        "class_schedule",
        "time_slot",
        ["slot_id"],
        ["slot_id"],
        ondelete="SET NULL",
    )
    op.execute(
        sa.text(
            """
            DELETE FROM time_slot ts
            WHERE ts.slot_id IN (
                '70380ca2-247c-4b49-9660-049117ec3f86',
                '7782c161-e58a-4861-9281-267d9f1eee62'
            )
            AND NOT EXISTS (
                SELECT 1 FROM class_schedule cs WHERE cs.slot_id = ts.slot_id
            )
            """
        )
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_class_schedule_slot_id",
        "class_schedule",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "fk_class_schedule_slot_id",
        "class_schedule",
        "time_slot",
        ["slot_id"],
        ["slot_id"],
        ondelete="CASCADE",
    )
    op.alter_column(
        "class_schedule",
        "slot_id",
        existing_type=sa.UUID(),
        nullable=False,
    )
    op.drop_column("class_schedule", "custom_end_time")
    op.drop_column("class_schedule", "custom_start_time")

