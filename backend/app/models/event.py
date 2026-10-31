from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UpdatedTimestampMixin

if TYPE_CHECKING:
    from app.models.audio_record import AudioRecord
    from app.models.user import User


class Event(UpdatedTimestampMixin, Base):
    """A user-owned recording event containing one or more audio records."""

    __tablename__ = "events"
    __table_args__ = (Index("ix_events_user_id_created_at", "user_id", "created_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str | None] = mapped_column(String(100), index=True)

    user: Mapped[User] = relationship(back_populates="events")
    audio_records: Mapped[list[AudioRecord]] = relationship(
        back_populates="event",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
