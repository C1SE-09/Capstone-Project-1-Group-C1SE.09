"""
app/models/report_response.py
=============================
SQLAlchemy 2.0 ORM Model: ReportResponse
------------------------------------------
Phản hồi của phụ huynh dưới báo cáo hằng ngày (kiểu "bình luận" phẳng,
giống bình luận Facebook: mọi tin nhắn nằm chung 1 danh sách theo thời gian,
không có cây reply lồng nhau).

Design decisions
~~~~~~~~~~~~~~~~
* **Phẳng, 1 bảng duy nhất.** Không dùng ``reply_to_id`` tự tham chiếu vì
  case của KinderLog chỉ có 2 bên trao đổi (phụ huynh ↔ giáo viên); một cây
  lồng sâu sẽ tốn công UI mà không mang lại giá trị gì thêm.
* Mọi tin nhắn (của phụ huynh lẫn của giáo viên) đều nằm chung bảng này →
  thread liền mạch, truy vấn 1 lần, sort ``created_at`` là ra toàn bộ.
* ``author_role`` được lưu riêng (snapshot) vì khi tài khoản user bị xoá
  thì ``users.role`` không còn đọc được — cần biết ai đã viết để hiển thị
  avatar/tên và quyết định ai đã đọc.
* ``is_read`` = giáo viên đã đọc phản hồi của phụ huynh (badge "2 phản hồi mới").
* ``is_resolved`` cho phép giáo viên đánh dấu từng phản hồi đã xử lý mà không
  cần mở thêm bảng/trạng thái riêng ở cấp báo cáo.
* Ảnh đính kèm dùng kho MinIO **private** (bucket riêng), trả về qua API có
  kiểm tra quyền — không dùng URL public. Xem
  ``app/services/private_medical_attachments.py``.

Entity hierarchy
~~~~~~~~~~~~~~~~
    DailyReport 1──* ReportResponse
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

# ---------------------------------------------------------------------------
# Forward-reference imports (avoid circular imports)
# ---------------------------------------------------------------------------
if TYPE_CHECKING:
    from app.models.child import Child
    from app.models.report import DailyReport
    from app.models.user import User


# ===========================================================================
# Enums
# ===========================================================================


class ResponseAuthorRole(str, enum.Enum):
    """Vai trò người viết phản hồi (snapshot tại thời điểm gửi)."""

    PARENT = "parent"
    TEACHER = "teacher"
    ADMIN = "admin"


# ===========================================================================
# ReportResponse
# ===========================================================================


class ReportResponse(Base, TimestampMixin):
    """Một tin nhắn phản hồi nằm trong phần "Phản hồi" của một báo cáo.

    Columns
    -------
    response_id      : UUID PK (auto-generated)
    daily_report_id  : FK → daily_report.daily_report_id (CASCADE DELETE)
    child_id         : FK → child.child_id (CASCADE DELETE) — bản sao để
                       phân quyền nhanh và đặt đường dẫn ảnh theo bé
    author_user_id   : FK → users.user_id (SET NULL) — người viết
    author_role      : ResponseAuthorRole – snapshot vai trò
    content          : Text – nội dung tin nhắn
    image_url        : Đường dẫn ảnh private (nullable) – KHÔNG phải URL public
    is_read          : Giáo viên đã đọc phản hồi này chưa
    is_resolved      : Giáo viên đã xử lý phản hồi này chưa
    resolved_at      : UTC timestamp khi đánh dấu đã xử lý (nullable)
    resolved_by_user_id : FK → users.user_id (SET NULL) – GV đã xử lý

    Relationships
    -------------
    daily_report : DailyReport – báo cáo cha
    child        : Child        – bé mà báo cáo thuộc về
    author       : User | None  – người viết
    """

    __tablename__ = "report_response"

    __table_args__ = (
        Index("ix_report_response_daily_report_id", "daily_report_id"),
        Index("ix_report_response_child_id", "child_id"),
        Index("ix_report_response_author_user_id", "author_user_id"),
        Index("ix_report_response_created_at", "created_at"),
        Index(
            "ix_report_response_unread",
            "daily_report_id",
            "author_role",
            "is_read",
        ),
        {"comment": "Parent/teacher replies attached under a daily report"},
    )

    # --- Primary key ---
    response_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Surrogate primary key (UUID v4)",
    )

    # --- Foreign keys ---
    daily_report_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "daily_report.daily_report_id",
            ondelete="CASCADE",
            name="fk_report_response_daily_report_id",
        ),
        nullable=False,
        comment="Báo cáo cha – cascades delete khi báo cáo bị xoá",
    )
    child_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "child.child_id",
            ondelete="CASCADE",
            name="fk_report_response_child_id",
        ),
        nullable=True,
        comment="Bé mà báo cáo thuộc về – dùng để phân quyền và đặt đường dẫn ảnh",
    )
    author_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "users.user_id",
            ondelete="SET NULL",
            name="fk_report_response_author_user_id",
        ),
        nullable=True,
        comment="Người viết phản hồi – NULL nếu tài khoản bị xoá",
    )
    resolved_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "users.user_id",
            ondelete="SET NULL",
            name="fk_report_response_resolved_by_user_id",
        ),
        nullable=True,
        comment="Giáo viên đã đánh dấu xử lý – NULL nếu tài khoản bị xoá",
    )

    # --- Content ---
    author_role: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        default=ResponseAuthorRole.PARENT.value,
        server_default=ResponseAuthorRole.PARENT.value,
        comment="Snapshot vai trò người viết: parent | teacher | admin",
    )
    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Nội dung phản hồi",
    )
    image_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment=(
            "Đường dẫn ảnh trong kho private (KHÔNG phải URL public). "
            "Đọc qua endpoint kèm kiểm tra quyền."
        ),
    )

    # --- Workflow flags ---
    is_read: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Giáo viên đã đọc phản hồi này chưa",
    )
    is_resolved: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Giáo viên đã xử lý phản hồi này chưa",
    )
    resolved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Thời điểm đánh dấu đã xử lý (UTC)",
    )

    # --- Relationships ---
    daily_report: Mapped[DailyReport] = relationship(
        "DailyReport",
        back_populates="responses",
        lazy="joined",
    )
    child: Mapped[Child | None] = relationship(
        "Child",
        back_populates="report_responses",
        lazy="joined",
    )
    author: Mapped[User | None] = relationship(
        "User",
        foreign_keys=[author_user_id],
        lazy="joined",
    )

    # --- Dunder ---
    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<ReportResponse id={self.response_id!s} "
            f"report_id={self.daily_report_id!s} role={self.author_role!r}>"
        )
