from __future__ import annotations

from enum import Enum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Enum as SqlEnum, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UpdatedTimestampMixin

if TYPE_CHECKING:
    from app.models.audio_record import AudioRecord


class ProcessingStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class ProcessingJob(UpdatedTimestampMixin, Base):
    """The persisted state of the STT-to-summary workflow for one audio record."""

    __tablename__ = "processing_jobs"
    __table_args__ = (
        Index("ix_processing_jobs_status_updated_at", "status", "updated_at"),
        CheckConstraint(
            "status IN ('pending', 'processing', 'completed', 'failed')",
            name="ck_processing_jobs_status",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    audio_record_id: Mapped[int] = mapped_column(
        ForeignKey("audio_records.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    status: Mapped[ProcessingStatus] = mapped_column(
        SqlEnum(
            ProcessingStatus,
            values_callable=lambda enum: [item.value for item in enum],
            name="processing_status",
            native_enum=False,
            create_constraint=False,
        ),
        default=ProcessingStatus.PENDING,
        nullable=False,
    )
    error_message: Mapped[str | None] = mapped_column(Text)

    audio_record: Mapped[AudioRecord] = relationship(back_populates="processing_job")
