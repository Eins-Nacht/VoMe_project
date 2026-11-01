from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UpdatedTimestampMixin

if TYPE_CHECKING:
    from app.models.event import Event
    from app.models.processing_job import ProcessingJob
    from app.models.transcript import Transcript


class AudioRecord(UpdatedTimestampMixin, Base):
    """Metadata for an audio file temporarily uploaded for processing."""

    __tablename__ = "audio_records"
    __table_args__ = (
        Index("ix_audio_records_event_id_created_at", "event_id", "created_at"),
        CheckConstraint("size >= 0", name="ck_audio_records_size_nonnegative"),
        CheckConstraint(
            "duration IS NULL OR duration >= 0",
            name="ck_audio_records_duration_nonnegative",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    event_id: Mapped[int] = mapped_column(
        ForeignKey("events.id", ondelete="CASCADE"), nullable=False, index=True
    )
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str | None] = mapped_column(String(1024), unique=True)
    format: Mapped[str] = mapped_column(String(20), nullable=False)
    size: Mapped[int] = mapped_column(Integer, nullable=False)
    duration: Mapped[float | None] = mapped_column(Float)
    client_recording_id: Mapped[str | None] = mapped_column(
        String(36), index=True
    )

    event: Mapped[Event] = relationship(back_populates="audio_records")
    transcript: Mapped[Transcript | None] = relationship(
        back_populates="audio_record",
        cascade="all, delete-orphan",
        uselist=False,
        passive_deletes=True,
    )
    processing_job: Mapped[ProcessingJob | None] = relationship(
        back_populates="audio_record",
        cascade="all, delete-orphan",
        uselist=False,
        passive_deletes=True,
    )
