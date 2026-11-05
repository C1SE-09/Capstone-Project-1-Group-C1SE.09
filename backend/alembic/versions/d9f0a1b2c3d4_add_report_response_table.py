"""add report_response table (parent/teacher replies under a daily report)

Revision ID: d9f0a1b2c3d4
Revises: c8e9f0a1b2c4
Create Date: 2026-11-04 23:30:00

User story: "Phản hồi báo cáo" — phụ huynh viết phản hồi (kiểu bình luận)
ngay dưới báo cáo hằng ngày đã gửi; giáo viên có thể trả lời và đánh dấu
đã xử lý.

- Tạo bảng `report_response` – mọi tin nhắn (phụ huynh + giáo viên) nằm
  chung 1 bảng, phẳng theo thời gian (không cây reply lồng nhau).
- `author_role` lưu snapshot vai trò vì `users.role` biến mất khi tài khoản
  bị xoá.
- Ảnh đính kèm trỏ tới kho MinIO private (bucket `-report-responses`);
  cột chỉ lưu đường dẫn nội bộ, đọc qua endpoint có kiểm tra quyền.

Ghi chú enum: cột `author_role` dùng VARCHAR (không phải PG ENUM) để tránh
phải `ALTER TYPE ... ADD VALUE` khi sau này thêm vai trò mới — enum Python
`ResponseAuthorRole` trong model vẫn là nguồn sự thật ở tầng ứng dụng.
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d9f0a1b2c3d4"
down_revision: str | Sequence[str] | None = "c8e9f0a1b2c4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Tạo bảng report_response + index."""
    op.create_table(
        "report_response",
        sa.Column(
            "response_id",
            sa.UUID(),
            nullable=False,
            comment="Surrogate primary key (UUID v4)",
        ),
        sa.Column(
            "daily_report_id",
            sa.UUID(),
            nullable=False,
            comment="Báo cáo cha – cascades delete khi báo cáo bị xoá",
        ),
        sa.Column(
            "child_id",
            sa.UUID(),
            nullable=True,
            comment="Bé mà báo cáo thuộc về – dùng để phân quyền và đặt đường dẫn ảnh",
        ),
        sa.Column(
            "author_user_id",
            sa.UUID(),
            nullable=True,
            comment="Người viết phản hồi – NULL nếu tài khoản bị xoá",
        ),
        sa.Column(
            "resolved_by_user_id",
            sa.UUID(),
            nullable=True,
            comment="Giáo viên đã đánh dấu xử lý – NULL nếu tài khoản bị xoá",
        ),
        sa.Column(
            "author_role",
            sa.String(length=10),
            nullable=False,
            server_default="parent",
            comment="Snapshot vai trò người viết: parent | teacher | admin",
        ),
        sa.Column(
            "content",
            sa.Text(),
            nullable=False,
            comment="Nội dung phản hồi",
        ),
        sa.Column(
            "image_url",
            sa.String(length=512),
            nullable=True,
            comment=(
                "Đường dẫn ảnh trong kho private (KHÔNG phải URL public). "
                "Đọc qua endpoint kèm kiểm tra quyền."
            ),
        ),
        sa.Column(
            "is_read",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="Giáo viên đã đọc phản hồi này chưa",
        ),
        sa.Column(
            "is_resolved",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="Giáo viên đã xử lý phản hồi này chưa",
        ),
        sa.Column(
            "resolved_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Thời điểm đánh dấu đã xử lý (UTC)",
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
            ["daily_report_id"],
            ["daily_report.daily_report_id"],
            name="fk_report_response_daily_report_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["child_id"],
            ["child.child_id"],
            name="fk_report_response_child_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["author_user_id"],
            ["users.user_id"],
            name="fk_report_response_author_user_id",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["resolved_by_user_id"],
            ["users.user_id"],
            name="fk_report_response_resolved_by_user_id",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("response_id"),
    )

    op.create_index(
        "ix_report_response_daily_report_id",
        "report_response",
        ["daily_report_id"],
    )
    op.create_index(
        "ix_report_response_child_id",
        "report_response",
        ["child_id"],
    )
    op.create_index(
        "ix_report_response_author_user_id",
        "report_response",
        ["author_user_id"],
    )
    op.create_index(
        "ix_report_response_created_at",
        "report_response",
        ["created_at"],
    )
    op.create_index(
        "ix_report_response_unread",
        "report_response",
        ["daily_report_id", "author_role", "is_read"],
    )


def downgrade() -> None:
    """Gỡ bảng report_response."""
    op.drop_index("ix_report_response_unread", table_name="report_response")
    op.drop_index("ix_report_response_created_at", table_name="report_response")
    op.drop_index("ix_report_response_author_user_id", table_name="report_response")
    op.drop_index("ix_report_response_child_id", table_name="report_response")
    op.drop_index("ix_report_response_daily_report_id", table_name="report_response")
    op.drop_table("report_response")
