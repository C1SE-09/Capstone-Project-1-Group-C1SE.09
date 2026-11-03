"""add stt dispatch tracking to voice_record

Revision ID: c8e9f0a1b2c4
Revises: b7d8e9f0a1b3
Create Date: 2026-11-03 08:15:00

Bổ sung cơ chế đảm bảo bản ghi âm luôn được STT xử lý:

- `voice_record.stt_dispatch_attempts` – số lần đã đẩy task STT vào queue.
- `voice_record.last_stt_dispatch_at`   – mốc thời gian đẩy gần nhất.

Nhờ 2 cột này, hệ thống biết được bản ghi nào đã "kẹt" (đang PENDING quá
lâu) và có thể đẩy lại task một cách có kiểm soát (giới hạn số lần) khi
worker audio (RunPod) bật lại hoặc khi giáo viên mở app lại.
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c8e9f0a1b2c4"
down_revision: str | Sequence[str] | None = "b7d8e9f0a1b3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Thêm 2 cột theo dõi dispatch STT."""
    op.add_column(
        "voice_record",
        sa.Column(
            "stt_dispatch_attempts",
            sa.Integer(),
            nullable=False,
            server_default="0",
            comment=(
                "Số lần đã đẩy task STT vào queue. Dùng để giới hạn số lần "
                "re-dispatch cho bản ghi kẹt (worker audio không chạy) và tránh "
                "spam queue."
            ),
        ),
    )
    op.add_column(
        "voice_record",
        sa.Column(
            "last_stt_dispatch_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Thời điểm đẩy task STT gần nhất (dùng để tính bản ghi bị kẹt)",
        ),
    )


def downgrade() -> None:
    """Gỡ 2 cột theo dõi dispatch STT."""
    op.drop_column("voice_record", "last_stt_dispatch_at")
    op.drop_column("voice_record", "stt_dispatch_attempts")
