"""add audio columns to report_response table

Revision ID: f2a3b4c5d6e7
Revises: e1f2a3b4c5d6
Create Date: 2026-11-19 11:20:00.000000

User story: "Tin nhắn thoại trong trao đổi báo cáo" — phụ huynh và giáo viên
có thể gửi tin nhắn thoại (voice message / audio note) trong phần trao đổi
phản hồi báo cáo hằng ngày.

- Thêm cột `audio_url` (VARCHAR(512), nullable=True): đường dẫn file âm thanh
  trong kho MinIO private (đọc qua endpoint có kiểm tra quyền).
- Thêm cột `audio_duration` (INTEGER, nullable=True): thời lượng âm thanh tính
  bằng giây (dùng để render waveform và hiển thị thời gian phát).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f2a3b4c5d6e7"
down_revision: str | Sequence[str] | None = "e1f2a3b4c5d6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Thêm audio_url và audio_duration vào bảng report_response."""
    op.add_column(
        "report_response",
        sa.Column(
            "audio_url",
            sa.String(length=512),
            nullable=True,
            comment=(
                "Đường dẫn file âm thanh trong kho private (KHÔNG phải URL public). "
                "Đọc qua endpoint kèm kiểm tra quyền."
            ),
        ),
    )
    op.add_column(
        "report_response",
        sa.Column(
            "audio_duration",
            sa.Integer(),
            nullable=True,
            comment="Thời lượng file âm thanh tính bằng giây",
        ),
    )


def downgrade() -> None:
    """Xóa cột audio_duration và audio_url khỏi bảng report_response."""
    op.drop_column("report_response", "audio_duration")
    op.drop_column("report_response", "audio_url")
