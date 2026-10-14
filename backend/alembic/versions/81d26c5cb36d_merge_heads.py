"""merge heads

Revision ID: 81d26c5cb36d
Revises: a1b2c3d4e5f6, fac3032a12f1
Create Date: 2026-10-14 12:34:05.035220

"""
from typing import Sequence, Union



# revision identifiers, used by Alembic.
revision: str = '81d26c5cb36d'
down_revision: Union[str, Sequence[str], None] = ('a1b2c3d4e5f6', 'fac3032a12f1')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
