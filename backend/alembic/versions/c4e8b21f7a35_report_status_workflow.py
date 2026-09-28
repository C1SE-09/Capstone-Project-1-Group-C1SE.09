"""report status workflow: draft/sent/read + sent_at/read_at

Revision ID: c4e8b21f7a35
Revises: 3a6146471483

CRITICAL: SQLAlchemy's sa.Enum persists the enum member NAME, not its value.
    DailyReportStatus.SENT  ->  name "SENT",  value "sent"
    -> the database stores 'SENT' (uppercase)

All SQL literals in this file must therefore be UPPERCASE.
The API still returns lowercase, because the response uses `.value`.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c4e8b21f7a35"
down_revision: str | Sequence[str] | None = "3a6146471483"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # 1. Add the new enum values.
    #
    # PostgreSQL cannot USE a new enum value in the same transaction that
    # added it ("unsafe use of new value of enum type"). autocommit_block()
    # commits the ALTER TYPE immediately so the backfill below can safely
    # reference 'SENT'.
    #
    # Values are UPPERCASE: sa.Enum stores the member name.
    # ------------------------------------------------------------------
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE daily_report_status_enum ADD VALUE IF NOT EXISTS 'SENT'")
        op.execute("ALTER TYPE daily_report_status_enum ADD VALUE IF NOT EXISTS 'READ'")

    # ------------------------------------------------------------------
    # 2. Backfill. Every existing 'PUBLISHED' row WAS already sent to the
    #    parent, so 'SENT' is the correct new value for all of them.
    # ------------------------------------------------------------------
    op.execute("UPDATE daily_report SET status = 'SENT' WHERE status = 'PUBLISHED'")

    # ------------------------------------------------------------------
    # 3. Timestamp fields. published_at is a DATE and cannot hold a time,
    #    so real timestamps get their own columns. published_at is kept
    #    because the Flutter client still reads it.
    # ------------------------------------------------------------------
    op.add_column(
        "daily_report",
        sa.Column(
            "sent_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="UTC timestamp when the teacher sent the report to the parent",
        ),
    )
    op.add_column(
        "daily_report",
        sa.Column(
            "read_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="UTC timestamp when the parent first opened the report",
        ),
    )

    # ------------------------------------------------------------------
    # 4. Backfill sent_at from the old date-only column.
    #    AT TIME ZONE 'UTC' pins midnight to UTC instead of the session
    #    timezone, which keeps the value stable across environments.
    # ------------------------------------------------------------------
    op.execute(
        "UPDATE daily_report "
        "SET sent_at = published_at::timestamp AT TIME ZONE 'UTC' "
        "WHERE published_at IS NOT NULL AND sent_at IS NULL"
    )


def downgrade() -> None:
    # Map the new states back onto the old ones.
    op.execute("UPDATE daily_report SET status = 'PUBLISHED' WHERE status = 'SENT'")
    op.execute("UPDATE daily_report SET status = 'PUBLISHED' WHERE status = 'READ'")

    op.drop_column("daily_report", "read_at")
    op.drop_column("daily_report", "sent_at")

    # NOTE: PostgreSQL cannot remove values from an enum type. 'SENT' and
    # 'READ' remain in daily_report_status_enum after downgrade. This is
    # harmless - no row references them.
