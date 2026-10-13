"""add_teacher_class_table

Revision ID: fac3032a12f1
Revises: c1c17a05262a
Create Date: 2026-10-13 15:15:05.400850

"""
from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'fac3032a12f1'
down_revision: str | Sequence[str] | None = 'c1c17a05262a'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS teacher_class (
            teacher_id UUID NOT NULL REFERENCES teacher(teacher_id) ON DELETE CASCADE,
            class_id UUID NOT NULL REFERENCES class(class_id) ON DELETE CASCADE,
            PRIMARY KEY (teacher_id, class_id)
        );
        INSERT INTO teacher_class (teacher_id, class_id)
        SELECT teacher_id, class_id FROM teacher
        WHERE class_id IS NOT NULL
        ON CONFLICT DO NOTHING;
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("teacher_class")
