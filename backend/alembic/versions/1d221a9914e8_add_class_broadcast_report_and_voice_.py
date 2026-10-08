"""add_class_broadcast_report_and_voice_scope

Revision ID: 1d221a9914e8
Revises: c4e8b21f7a35
Create Date: 2026-09-27 10:56:27.514066

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "1d221a9914e8"
down_revision: str | Sequence[str] | None = "c4e8b21f7a35"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # 0. Ensure PostgreSQL ENUM types for add_column exist before referencing them
    sa.dialects.postgresql.ENUM(
        "single_child", "whole_class", name="voice_record_scope_enum"
    ).create(op.get_bind(), checkfirst=True)

    sa.dialects.postgresql.ENUM(
        "individual", "exception", name="daily_report_type_enum"
    ).create(op.get_bind(), checkfirst=True)

    # 1. VoiceRecord changes: scope & class_id
    scope_enum = sa.Enum("single_child", "whole_class", name="voice_record_scope_enum")
    scope_enum.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "voice_record",
        sa.Column(
            "scope",
            sa.dialects.postgresql.ENUM(
                "single_child",
                "whole_class",
                name="voice_record_scope_enum",
                create_type=False,
            ),
            server_default="single_child",
            nullable=False,
            comment="Scope of recording: single_child or whole_class",
        ),
    )
    op.add_column(
        "voice_record",
        sa.Column(
            "class_id",
            sa.UUID(),
            nullable=True,
            comment="Target class for whole_class recording – NULL for single_child",
        ),
    )
    op.create_foreign_key(
        "fk_voice_record_class_id",
        "voice_record",
        "class",
        ["class_id"],
        ["class_id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_voice_record_scope", "voice_record", ["scope"], unique=False)
    op.create_index(
        "ix_voice_record_class_id", "voice_record", ["class_id"], unique=False
    )

    # 2. Create class_broadcast_report table
    op.create_table(
        "class_broadcast_report",
        sa.Column(
            "broadcast_report_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "voice_record_id",
            sa.UUID(),
            nullable=True,
            comment="Source voice recording – NULL if created manually",
        ),
        sa.Column(
            "class_id",
            sa.UUID(),
            nullable=True,
            comment="Class receiving this broadcast report",
        ),
        sa.Column(
            "teacher_id",
            sa.UUID(),
            nullable=True,
            comment="Teacher who created the broadcast report",
        ),
        sa.Column(
            "report_date",
            sa.Date(),
            nullable=False,
            comment="Calendar date covered by this broadcast report",
        ),
        sa.Column(
            "common_meals",
            sa.Text(),
            nullable=True,
            comment="Common meal information for the whole class",
        ),
        sa.Column(
            "common_sleeping",
            sa.Text(),
            nullable=True,
            comment="Common sleep/nap information for the whole class",
        ),
        sa.Column(
            "common_health",
            sa.Text(),
            nullable=True,
            comment="Common health information for the whole class",
        ),
        sa.Column(
            "common_activities",
            sa.Text(),
            nullable=True,
            comment="Common learning/play activities for the whole class",
        ),
        sa.Column(
            "common_mood",
            sa.Text(),
            nullable=True,
            comment="Common mood/general sentiment for the whole class",
        ),
        sa.Column(
            "common_notes",
            sa.Text(),
            nullable=True,
            comment="General notes or extra reminders for parents",
        ),
        sa.Column(
            "included_child_ids",
            sa.JSON(),
            nullable=True,
            comment="List of child IDs (UUID strings) receiving the broadcast report",
        ),
        sa.Column(
            "excluded_child_ids",
            sa.JSON(),
            nullable=True,
            comment="List of child IDs (UUID strings) with individual exception reports",
        ),
        sa.Column(
            "status",
            sa.Enum("draft", "sent", name="broadcast_report_status_enum"),
            server_default="draft",
            nullable=False,
            comment="Publication lifecycle: draft → sent",
        ),
        sa.Column(
            "sent_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="UTC timestamp when the broadcast report was sent to parents",
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
            ["voice_record_id"],
            ["voice_record.voice_record_id"],
            name="fk_broadcast_voice_record_id",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["class_id"],
            ["class.class_id"],
            name="fk_broadcast_class_id",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["teacher_id"],
            ["teacher.teacher_id"],
            name="fk_broadcast_teacher_id",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("broadcast_report_id"),
        sa.UniqueConstraint("class_id", "report_date", name="uq_broadcast_class_date"),
        comment="Broadcast daily reports summarizing common class activities",
    )
    op.create_index(
        "ix_broadcast_class_id", "class_broadcast_report", ["class_id"], unique=False
    )
    op.create_index(
        "ix_broadcast_teacher_id",
        "class_broadcast_report",
        ["teacher_id"],
        unique=False,
    )
    op.create_index(
        "ix_broadcast_report_date",
        "class_broadcast_report",
        ["report_date"],
        unique=False,
    )
    op.create_index(
        "ix_broadcast_status", "class_broadcast_report", ["status"], unique=False
    )

    # 3. DailyReport changes: report_type & source_broadcast_id
    report_type_enum = sa.Enum("individual", "exception", name="daily_report_type_enum")
    report_type_enum.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "daily_report",
        sa.Column(
            "report_type",
            sa.dialects.postgresql.ENUM(
                "individual",
                "exception",
                name="daily_report_type_enum",
                create_type=False,
            ),
            server_default="individual",
            nullable=False,
            comment="Origin type: individual or exception",
        ),
    )
    op.add_column(
        "daily_report",
        sa.Column(
            "source_broadcast_id",
            sa.UUID(),
            nullable=True,
            comment="Linked broadcast report if exception type",
        ),
    )
    op.create_foreign_key(
        "fk_daily_report_source_broadcast_id",
        "daily_report",
        "class_broadcast_report",
        ["source_broadcast_id"],
        ["broadcast_report_id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_daily_report_report_type", "daily_report", ["report_type"], unique=False
    )
    op.create_index(
        "ix_daily_report_source_broadcast_id",
        "daily_report",
        ["source_broadcast_id"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_daily_report_source_broadcast_id", table_name="daily_report")
    op.drop_index("ix_daily_report_report_type", table_name="daily_report")
    op.drop_constraint(
        "fk_daily_report_source_broadcast_id", "daily_report", type_="foreignkey"
    )
    op.drop_column("daily_report", "source_broadcast_id")
    op.drop_column("daily_report", "report_type")

    op.drop_index("ix_broadcast_status", table_name="class_broadcast_report")
    op.drop_index("ix_broadcast_report_date", table_name="class_broadcast_report")
    op.drop_index("ix_broadcast_teacher_id", table_name="class_broadcast_report")
    op.drop_index("ix_broadcast_class_id", table_name="class_broadcast_report")
    op.drop_table("class_broadcast_report")

    op.drop_index("ix_voice_record_class_id", table_name="voice_record")
    op.drop_index("ix_voice_record_scope", table_name="voice_record")
    op.drop_constraint("fk_voice_record_class_id", "voice_record", type_="foreignkey")
    op.drop_column("voice_record", "class_id")
    op.drop_column("voice_record", "scope")

    op.execute("DROP TYPE IF EXISTS daily_report_type_enum")
    op.execute("DROP TYPE IF EXISTS broadcast_report_status_enum")
    op.execute("DROP TYPE IF EXISTS voice_record_scope_enum")
