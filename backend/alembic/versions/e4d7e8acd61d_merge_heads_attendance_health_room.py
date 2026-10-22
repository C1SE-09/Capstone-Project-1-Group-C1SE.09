"""merge_heads_attendance_health_room

Revision ID: e4d7e8acd61d
Revises: 3756965ba6b9, c1a2b3c4d5e6, c5e6f7a8b9c0
Create Date: 2026-10-22 09:27:03.113396

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e4d7e8acd61d'
down_revision: Union[str, Sequence[str], None] = ('3756965ba6b9', 'c1a2b3c4d5e6', 'c5e6f7a8b9c0')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
