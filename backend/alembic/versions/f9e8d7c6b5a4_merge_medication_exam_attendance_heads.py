"""merge medication, health exam, and attendance heads

Revision ID: f9e8d7c6b5a4
Revises: a2b3c4d5e6f7, b7c8d9e0f1a2, c7d8e9f0a1b2
Create Date: 2026-10-29 16:45:00.000000

"""
from typing import Sequence, Union



# revision identifiers, used by Alembic.
revision: str = 'f9e8d7c6b5a4'
down_revision: Union[str, Sequence[str], None] = ('a2b3c4d5e6f7', 'b7c8d9e0f1a2', 'c7d8e9f0a1b2')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
