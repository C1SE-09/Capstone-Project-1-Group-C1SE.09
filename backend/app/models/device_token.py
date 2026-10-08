import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.user import User

class DeviceToken(Base, TimestampMixin):
    __tablename__ = "device_tokens"

    __table_args__ = (
        UniqueConstraint("user_id", "token", name="uq_user_device_token"),
        Index("ix_device_tokens_user_id", "user_id"),
    )

    device_token_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        ForeignKey(
            "users.user_id", 
            ondelete="CASCADE",
            name="fk_device_tokens_user_id_users"
        ),
        nullable=False,
    )

    token: Mapped[str] = mapped_column(
        String(512),
        nullable=False,
    )

    device_type: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    user: Mapped["User"] = relationship(
        "User",
        lazy="joined"
    )

    def __repr__(self) -> str:
        return (
            f"<DeviceToken id={self.device_token_id!s} "
            f"user_id={self.user_id!s}>"
        )