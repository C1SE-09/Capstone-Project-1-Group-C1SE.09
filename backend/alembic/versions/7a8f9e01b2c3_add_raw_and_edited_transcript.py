"""add raw_transcript and edited_transcript to voice_record

Revision ID: 7a8f9e01b2c3
Revises: 6004cb8a3f33
Create Date: 2026-09-09 10:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "7a8f9e01b2c3"
down_revision: str | Sequence[str] | None = "6004cb8a3f33"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "voice_record",
        sa.Column(
            "raw_transcript",
            sa.Text(),
            nullable=True,
            comment="Original AI speech-to-text transcript",
        ),
    )
    op.add_column(
        "voice_record",
        sa.Column(
            "edited_transcript",
            sa.Text(),
            nullable=True,
            comment="Teacher-edited transcript",
        ),
    )


def downgrade() -> None:
    op.drop_column("voice_record", "edited_transcript")
    op.drop_column("voice_record", "raw_transcript")
