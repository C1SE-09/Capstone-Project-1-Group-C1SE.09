"""add bug report tables

Revision ID: c1c17a05262a
Revises: e3fa1008e0bb
Create Date: 2026-10-12 19:51:24.997712

TASK: TASK-B-01 – Bug Report Models

NOTE on PostgreSQL ENUM lifecycle
----------------------------------
PostgreSQL ENUM types are not automatically dropped when a table is dropped.
We therefore explicitly create the types at the start of ``upgrade()`` and
drop them at the end of ``downgrade()``. Column references use
``create_type=False`` so SQLAlchemy does not attempt to re-create them
during ``op.create_table``.
"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c1c17a05262a"
down_revision: str | Sequence[str] | None = "e3fa1008e0bb"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


# Column-level ENUM references (create_type=False to avoid duplicate CREATE TYPE)
BUG_CATEGORY = postgresql.ENUM(
    "ui", "performance", "crash", "data", "notification",
    "network", "auth", "other",
    name="bug_category_enum",
    create_type=False,
)
BUG_SEVERITY = postgresql.ENUM(
    "low", "medium", "high", "critical",
    name="bug_severity_enum",
    create_type=False,
)
BUG_STATUS = postgresql.ENUM(
    "open", "in_progress", "resolved", "closed", "wont_fix",
    name="bug_status_enum",
    create_type=False,
)


def upgrade() -> None:
    """Upgrade schema - add 3 bug_report tables + 3 enum types."""

    # ------------------------------------------------------------------------
    # Create ENUM types (shared across multiple tables)
    # ------------------------------------------------------------------------
    bug_category_t = postgresql.ENUM(
        "ui", "performance", "crash", "data", "notification",
        "network", "auth", "other",
        name="bug_category_enum",
    )
    bug_severity_t = postgresql.ENUM(
        "low", "medium", "high", "critical",
        name="bug_severity_enum",
    )
    bug_status_t = postgresql.ENUM(
        "open", "in_progress", "resolved", "closed", "wont_fix",
        name="bug_status_enum",
    )
    bug_category_t.create(op.get_bind(), checkfirst=True)
    bug_severity_t.create(op.get_bind(), checkfirst=True)
    bug_status_t.create(op.get_bind(), checkfirst=True)

    # ------------------------------------------------------------------------
    # bug_report
    # ------------------------------------------------------------------------
    op.create_table(
        "bug_report",
        sa.Column(
            "bug_report_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "user_id",
            sa.UUID(),
            nullable=False,
            comment="User who reported the bug – NULL if user is deleted",
        ),
        sa.Column(
            "teacher_id",
            sa.UUID(),
            nullable=True,
            comment="Assigned developer/teacher – NULL if not yet assigned",
        ),
        sa.Column(
            "title",
            sa.String(length=200),
            nullable=False,
            comment="Short summary of the bug, e.g. 'App crash khi mở thông báo'",
        ),
        sa.Column(
            "description",
            sa.Text(),
            nullable=False,
            comment="Detailed description of what happened, steps to reproduce, etc.",
        ),
        sa.Column("category", BUG_CATEGORY.copy(), server_default="other", nullable=False, comment="Type/category of the bug"),
        sa.Column("severity", BUG_SEVERITY.copy(), server_default="medium", nullable=False, comment="Severity level for triaging"),
        sa.Column("status", BUG_STATUS.copy(), server_default="open", nullable=False, comment="Current lifecycle status of the bug report"),
        sa.Column(
            "app_version",
            sa.String(length=50),
            nullable=True,
            comment="Flutter app version, e.g. '1.2.3'",
        ),
        sa.Column(
            "build_number",
            sa.String(length=50),
            nullable=True,
            comment="Build number, e.g. '42'",
        ),
        sa.Column(
            "os_version",
            sa.String(length=100),
            nullable=True,
            comment="Device OS version, e.g. 'Android 14' or 'iOS 17.2'",
        ),
        sa.Column(
            "device_model",
            sa.String(length=200),
            nullable=True,
            comment="Device model name, e.g. 'Samsung Galaxy S23'",
        ),
        sa.Column(
            "network_type",
            sa.String(length=20),
            nullable=True,
            comment="Network type when bug occurred: wifi | cellular | offline",
        ),
        sa.Column(
            "resolved_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="UTC timestamp when the bug was marked as resolved",
        ),
        sa.Column(
            "closed_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="UTC timestamp when the bug report was closed",
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
            ["teacher_id"],
            ["teacher.teacher_id"],
            name="fk_bug_report_teacher_id",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.user_id"],
            name="fk_bug_report_user_id",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("bug_report_id"),
        comment="Bug/issue reports submitted by app users",
    )
    op.create_index("ix_bug_report_app_version", "bug_report", ["app_version"], unique=False)
    op.create_index("ix_bug_report_category", "bug_report", ["category"], unique=False)
    op.create_index("ix_bug_report_created_at", "bug_report", ["created_at"], unique=False)
    op.create_index("ix_bug_report_severity", "bug_report", ["severity"], unique=False)
    op.create_index("ix_bug_report_status", "bug_report", ["status"], unique=False)
    op.create_index("ix_bug_report_teacher_id", "bug_report", ["teacher_id"], unique=False)
    op.create_index("ix_bug_report_user_id", "bug_report", ["user_id"], unique=False)

    # ------------------------------------------------------------------------
    # bug_report_attachment
    # ------------------------------------------------------------------------
    op.create_table(
        "bug_report_attachment",
        sa.Column(
            "attachment_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "bug_report_id",
            sa.UUID(),
            nullable=False,
            comment="Parent bug report – cascades delete",
        ),
        sa.Column(
            "file_url",
            sa.String(length=512),
            nullable=False,
            comment="Full URL to the file in MinIO / S3",
        ),
        sa.Column(
            "file_name",
            sa.String(length=255),
            nullable=False,
            comment="Original file name as uploaded, e.g. 'screenshot_2024.png'",
        ),
        sa.Column(
            "file_size",
            sa.Integer(),
            nullable=True,
            comment="File size in bytes",
        ),
        sa.Column(
            "mime_type",
            sa.String(length=100),
            nullable=True,
            comment="MIME type, e.g. 'image/png' or 'text/plain'",
        ),
        sa.Column(
            "description",
            sa.String(length=500),
            nullable=True,
            comment="Optional description of what this attachment shows",
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
            ["bug_report_id"],
            ["bug_report.bug_report_id"],
            name="fk_bug_report_attachment_report_id",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("attachment_id"),
        comment="File attachments (screenshots, logs) for bug reports",
    )
    op.create_index(
        "ix_bug_report_attachment_report_id",
        "bug_report_attachment",
        ["bug_report_id"],
        unique=False,
    )

    # ------------------------------------------------------------------------
    # bug_report_history
    # ------------------------------------------------------------------------
    op.create_table(
        "bug_report_history",
        sa.Column(
            "history_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "bug_report_id",
            sa.UUID(),
            nullable=False,
            comment="Parent bug report – cascades delete",
        ),
        sa.Column(
            "changed_by_id",
            sa.UUID(),
            nullable=True,
            comment="User who made this change – NULL if user is deleted",
        ),
        sa.Column("old_status", BUG_STATUS.copy(), nullable=True, comment="Previous status before this change (NULL for initial OPEN)"),
        sa.Column("new_status", BUG_STATUS.copy(), nullable=True, comment="New status after this change (NULL if only assignee changed)"),
        sa.Column(
            "old_teacher_id",
            sa.UUID(),
            nullable=True,
            comment="Previous assigned teacher before this change",
        ),
        sa.Column(
            "new_teacher_id",
            sa.UUID(),
            nullable=True,
            comment="New assigned teacher after this change",
        ),
        sa.Column(
            "comment",
            sa.Text(),
            nullable=True,
            comment="Optional note explaining why the change was made",
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
            ["bug_report_id"],
            ["bug_report.bug_report_id"],
            name="fk_bug_report_history_report_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["changed_by_id"],
            ["users.user_id"],
            name="fk_bug_report_history_changed_by_id",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["new_teacher_id"],
            ["teacher.teacher_id"],
            name="fk_bug_report_history_new_teacher_id",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["old_teacher_id"],
            ["teacher.teacher_id"],
            name="fk_bug_report_history_old_teacher_id",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("history_id"),
        comment="Audit trail of status and assignment changes for bug reports",
    )
    op.create_index(
        "ix_bug_report_history_changed_by_id",
        "bug_report_history",
        ["changed_by_id"],
        unique=False,
    )
    op.create_index(
        "ix_bug_report_history_created_at",
        "bug_report_history",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_bug_report_history_report_id",
        "bug_report_history",
        ["bug_report_id"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema - drop 3 bug_report tables and 3 enum types."""

    op.drop_index(
        "ix_bug_report_history_report_id", table_name="bug_report_history"
    )
    op.drop_index(
        "ix_bug_report_history_created_at", table_name="bug_report_history"
    )
    op.drop_index(
        "ix_bug_report_history_changed_by_id", table_name="bug_report_history"
    )
    op.drop_table("bug_report_history")

    op.drop_index(
        "ix_bug_report_attachment_report_id", table_name="bug_report_attachment"
    )
    op.drop_table("bug_report_attachment")

    op.drop_index("ix_bug_report_user_id", table_name="bug_report")
    op.drop_index("ix_bug_report_teacher_id", table_name="bug_report")
    op.drop_index("ix_bug_report_status", table_name="bug_report")
    op.drop_index("ix_bug_report_severity", table_name="bug_report")
    op.drop_index("ix_bug_report_created_at", table_name="bug_report")
    op.drop_index("ix_bug_report_category", table_name="bug_report")
    op.drop_index("ix_bug_report_app_version", table_name="bug_report")
    op.drop_table("bug_report")

    # ------------------------------------------------------------------------
    # Drop ENUM types (after tables are dropped so FK references are gone)
    # ------------------------------------------------------------------------
    op.execute("DROP TYPE IF EXISTS bug_status_enum")
    op.execute("DROP TYPE IF EXISTS bug_severity_enum")
    op.execute("DROP TYPE IF EXISTS bug_category_enum")
