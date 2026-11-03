"""add voice_recording_session (multi-clip recording sessions)

Revision ID: b7d8e9f0a1b3
Revises: a1b2c3d4e5f7
Create Date: 2026-11-03 07:30:00

User story: "Giữ nhiều lần ghi âm rồi gửi trích xuất một lần".

- Tạo bảng `voice_recording_session` gom nhiều bản ghi âm của cùng 1 phiên
  (cùng giáo viên + lớp + ngày).
- Thêm cột `voice_record.session_id` trỏ về phiên (NULL cho bản ghi legacy).
- `session.representative_voice_record_id` là bản ghi đại diện, nơi lưu
  `extraction_result` sau khi phân tích transcript gộp.

FK vòng (voice_record.session_id ↔ session.representative_voice_record_id):
- `voice_record.session_id` tạo cùng lúc bảng session (FK thường).
- `session.representative_voice_record_id` tạo bằng ALTER riêng sau khi
  bảng `voice_record` đã có (tương đương `use_alter=True` trong ORM).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b7d8e9f0a1b3"
down_revision: str | Sequence[str] | None = "a1b2c3d4e5f7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Tạo bảng session + cột session_id trên voice_record."""
    # ------------------------------------------------------------------
    # 1. Tạo bảng voice_recording_session (chưa có FK vòng)
    # ------------------------------------------------------------------
    op.create_table(
        "voice_recording_session",
        sa.Column(
            "session_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "teacher_id",
            sa.UUID(),
            nullable=True,
            comment="Teacher who owns the session – NULL if teacher is deleted",
        ),
        sa.Column(
            "class_id",
            sa.UUID(),
            nullable=True,
            comment="Target class of the session – NULL for single_child sessions",
        ),
        sa.Column(
            "child_id",
            sa.UUID(),
            nullable=True,
            comment="Subject child for single_child sessions – NULL for whole_class",
        ),
        sa.Column(
            "scope",
            # Enum này đã tồn tại từ migration tạo voice_record → tái sử dụng,
            # không CREATE TYPE lại (sẽ lỗi "type already exists").
            postgresql.ENUM(
                "single_child",
                "whole_class",
                name="voice_record_scope_enum",
                create_type=False,
            ),
            server_default="whole_class",
            nullable=False,
            comment="Scope of the session: single_child or whole_class",
        ),
        sa.Column(
            "recorded_at",
            sa.Date(),
            nullable=True,
            comment="Date the session belongs to (defaults to today in VN timezone)",
        ),
        sa.Column(
            "status",
            sa.Enum(
                "active",
                "merged",
                "discarded",
                name="voice_recording_session_status_enum",
            ),
            server_default="active",
            nullable=False,
            comment="Session lifecycle: active → merged | discarded",
        ),
        sa.Column(
            "merged_transcript",
            sa.Text(),
            nullable=True,
            comment="Transcript gộp của tất cả bản ghi trong phiên (NULL trước khi gửi)",
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
        sa.PrimaryKeyConstraint("session_id"),
        sa.ForeignKeyConstraint(
            ["teacher_id"],
            ["teacher.teacher_id"],
            name="fk_voice_recording_session_teacher_id",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["class_id"],
            ["class.class_id"],
            name="fk_voice_recording_session_class_id",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["child_id"],
            ["child.child_id"],
            name="fk_voice_recording_session_child_id",
            ondelete="SET NULL",
        ),
        comment="Recording sessions that group multiple voice clips for one merge",
    )

    op.create_index(
        "ix_voice_recording_session_teacher_id",
        "voice_recording_session",
        ["teacher_id"],
        unique=False,
    )
    op.create_index(
        "ix_voice_recording_session_class_id",
        "voice_recording_session",
        ["class_id"],
        unique=False,
    )
    op.create_index(
        "ix_voice_recording_session_recorded_at",
        "voice_recording_session",
        ["recorded_at"],
        unique=False,
    )
    op.create_index(
        "ix_voice_recording_session_status",
        "voice_recording_session",
        ["status"],
        unique=False,
    )

    # ------------------------------------------------------------------
    # 2. Thêm session_id + clip_order vào voice_record
    # ------------------------------------------------------------------
    op.add_column(
        "voice_record",
        sa.Column(
            "session_id",
            sa.UUID(),
            nullable=True,
            comment=(
                "Phiên ghi âm chứa bản ghi này – NULL cho bản ghi đơn lẻ (legacy) "
                "hoặc khi phiên đã bị xoá"
            ),
        ),
    )
    op.add_column(
        "voice_record",
        sa.Column(
            "clip_order",
            sa.Integer(),
            nullable=True,
            comment=(
                "Thứ tự bản ghi trong phiên (0, 1, 2...). Dùng để gộp transcript "
                "theo đúng thứ tự ghi – created_at không đủ tin cậy vì nhiều bản "
                "có thể trùng timestamp."
            ),
        ),
    )
    op.create_foreign_key(
        "fk_voice_record_session_id",
        "voice_record",
        "voice_recording_session",
        ["session_id"],
        ["session_id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_voice_record_session_id",
        "voice_record",
        ["session_id"],
        unique=False,
    )

    # ------------------------------------------------------------------
    # 3. FK vòng: session.representative_voice_record_id
    #    Tạo SAU cột session_id để tránh xung đột thứ tự FK.
    # ------------------------------------------------------------------
    op.add_column(
        "voice_recording_session",
        sa.Column(
            "representative_voice_record_id",
            sa.UUID(),
            nullable=True,
            comment="Bản ghi đại diện – nơi lưu extraction_result sau khi phân tích",
        ),
    )
    op.create_foreign_key(
        "fk_voice_recording_session_representative_voice_record_id",
        "voice_recording_session",
        "voice_record",
        ["representative_voice_record_id"],
        ["voice_record_id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    """Xoá bảng session + cột session_id trên voice_record."""
    op.drop_constraint(
        "fk_voice_recording_session_representative_voice_record_id",
        "voice_recording_session",
        type_="foreignkey",
    )
    op.drop_column("voice_recording_session", "representative_voice_record_id")

    op.drop_index("ix_voice_record_session_id", table_name="voice_record")
    op.drop_constraint(
        "fk_voice_record_session_id",
        "voice_record",
        type_="foreignkey",
    )
    op.drop_column("voice_record", "clip_order")
    op.drop_column("voice_record", "session_id")

    op.drop_index("ix_voice_recording_session_status", table_name="voice_recording_session")
    op.drop_index(
        "ix_voice_recording_session_recorded_at",
        table_name="voice_recording_session",
    )
    op.drop_index("ix_voice_recording_session_class_id", table_name="voice_recording_session")
    op.drop_index(
        "ix_voice_recording_session_teacher_id",
        table_name="voice_recording_session",
    )
    op.drop_table("voice_recording_session")
