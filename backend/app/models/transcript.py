from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UpdatedTimestampMixin

if TYPE_CHECKING:
    from app.models.audio_record import AudioRecord
    from app.models.summary import Summary


class Transcript(UpdatedTimestampMixin, Base):
    """Optional transcription result for an audio record."""

    __tablename__ = "transcripts"

    id: Mapped[int] = mapped_column(primary_key=True)
    audio_record_id: Mapped[int] = mapped_column(
        ForeignKey("audio_records.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    text: Mapped[str] = mapped_column(Text, nullable=False)
    language: Mapped[str | None] = mapped_column(String(20))

    audio_record: Mapped[AudioRecord] = relationship(back_populates="transcript")
    summary: Mapped[Summary | None] = relationship(
        back_populates="transcript",
        cascade="all, delete-orphan",
        uselist=False,
        passive_deletes=True,
    )
