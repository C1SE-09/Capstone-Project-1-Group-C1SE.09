"""add child health profile columns and backfill legacy allergies

Revision ID: c1a2b3c4d5e6
Revises: b4c5d6e7f8a9
Create Date: 2026-10-21 08:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "c1a2b3c4d5e6"
down_revision: Union[str, Sequence[str], None] = "b4c5d6e7f8a9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "child",
        sa.Column(
            "allergy_status",
            sa.String(length=16),
            nullable=False,
            server_default="unknown",
            comment="Trạng thái dị ứng: unknown | none | present",
        ),
    )
    op.add_column(
        "child",
        sa.Column(
            "care_notes",
            sa.Text(),
            nullable=True,
            comment="Lưu ý chăm sóc lâu dài, tách khỏi mô tả dị ứng",
        ),
    )
    op.add_column(
        "child",
        sa.Column("health_updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "child",
        sa.Column(
            "health_updated_by_user_id",
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.add_column(
        "child",
        sa.Column("health_update_source", sa.String(length=16), nullable=True),
    )
    op.add_column(
        "child",
        sa.Column(
            "health_version",
            sa.Integer(),
            nullable=False,
            server_default="1",
        ),
    )
    op.create_foreign_key(
        "fk_child_health_updated_by_user_id",
        "child",
        "users",
        ["health_updated_by_user_id"],
        ["user_id"],
        ondelete="SET NULL",
    )

    # Phân loại dữ liệu dị ứng cũ: rỗng/không có ⇒ unknown/none, còn lại ⇒ present.
    op.execute(
        """
        UPDATE child SET allergy_status = CASE
          WHEN medical_allergies IS NULL OR btrim(medical_allergies) = '' THEN 'unknown'
          WHEN lower(btrim(medical_allergies)) IN ('không có', 'không', 'none') THEN 'none'
          ELSE 'present'
        END
        """
    )
    op.execute(
        "UPDATE child SET health_update_source = 'legacy' "
        "WHERE allergy_status <> 'unknown'"
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_child_health_updated_by_user_id", "child", type_="foreignkey"
    )
    op.drop_column("child", "health_version")
    op.drop_column("child", "health_update_source")
    op.drop_column("child", "health_updated_by_user_id")
    op.drop_column("child", "health_updated_at")
    op.drop_column("child", "care_notes")
    op.drop_column("child", "allergy_status")
