"""merge heads: leave_request + health_examinations

Revision ID: ae06abd00007
Revises: 4d8e9f1a2b3c, c0b673468361
Create Date: 2026-10-28 11:58:52.373329

"""
from typing import Sequence, Union

# revision identifiers, used by Alembic.
revision: str = 'ae06abd00007'
down_revision: Union[str, Sequence[str], None] = ('4d8e9f1a2b3c', 'c0b673468361')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
