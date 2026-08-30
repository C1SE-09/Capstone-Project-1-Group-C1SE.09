"""
SQLAlchemy 2.0 Declarative Base & Shared Mixins
================================================
Provides:
- ``Base``         : DeclarativeBase subclass used by ALL ORM models.
- ``TimestampMixin``: Adds ``created_at`` / ``updated_at`` columns automatically.
"""

from datetime import datetime, timezone

from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Central declarative base for the entire ADARK application."""

    # Allow SQLAlchemy to inherit __tablename__ convention from subclasses
    pass


class TimestampMixin:
    """Mixin that adds audit timestamp columns to any model.

    Columns
    -------
    created_at : datetime (UTC)
        Set once at INSERT time via the database ``now()`` function.
    updated_at : datetime (UTC)
        Refreshed automatically on every UPDATE via ``onupdate``.
    """

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
