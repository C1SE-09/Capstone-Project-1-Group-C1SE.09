"""create parent_child table and migrate existing data

Revision ID: b4c5d6e7f8a9
Revises: ed2f8a1c582f
Create Date: 2026-10-18 20:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "b4c5d6e7f8a9"
down_revision: Union[str, Sequence[str], None] = "ed2f8a1c582f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create table parent_child
    op.create_table(
        "parent_child",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
            comment="Surrogate primary key",
        ),
        sa.Column(
            "parent_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("parent.parent_id", ondelete="CASCADE", name="fk_parent_child_parent_id"),
            nullable=False,
            comment="Foreign key to parent table",
        ),
        sa.Column(
            "child_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("child.child_id", ondelete="CASCADE", name="fk_parent_child_child_id"),
            nullable=False,
            comment="Foreign key to child table",
        ),
        sa.Column(
            "relationship",
            sa.String(length=30),
            nullable=True,
            comment="Quan hệ với bé (vd: Bố, Mẹ, Ông, Bà, Người giám hộ)",
        ),
        sa.Column(
            "is_primary",
            sa.Boolean(),
            server_default="false",
            nullable=False,
            comment="True nếu là người liên hệ chính",
        ),
        sa.Column(
            "can_pickup",
            sa.Boolean(),
            server_default="true",
            nullable=False,
            comment="True nếu có quyền đưa đón trẻ",
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
        sa.UniqueConstraint("parent_id", "child_id", name="uq_parent_child"),
        comment="Many-to-many relationship between parent and child with roles and permissions",
    )

    # 2. Create indexes
    op.create_index("ix_parent_child_parent_id", "parent_child", ["parent_id"], unique=False)
    op.create_index("ix_parent_child_child_id", "parent_child", ["child_id"], unique=False)

    # 3. Data migration: copy existing child.parent_id links into parent_child
    op.execute(
        """
        INSERT INTO parent_child (id, parent_id, child_id, relationship, is_primary, can_pickup, created_at, updated_at)
        SELECT
            gen_random_uuid(),
            c.parent_id,
            c.child_id,
            COALESCE(p.relationship, 'Phụ huynh'),
            true,
            true,
            now(),
            now()
        FROM child c
        JOIN parent p ON c.parent_id = p.parent_id
        WHERE c.parent_id IS NOT NULL
        ON CONFLICT (parent_id, child_id) DO NOTHING;
        """
    )


def downgrade() -> None:
    op.drop_index("ix_parent_child_child_id", table_name="parent_child")
    op.drop_index("ix_parent_child_parent_id", table_name="parent_child")
    op.drop_table("parent_child")
