from __future__ import annotations

from enum import Enum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Enum as SqlEnum, ForeignKey, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UpdatedTimestampMixin

if TYPE_CHECKING:
    from app.models.transcript import Transcript


class Mood(str, Enum):
    POSITIVE = "Positive"
    NEUTRAL = "Neutral"
    NEGATIVE = "Negative"


class ActionStatus(str, Enum):
    PENDING = "Pending"
    COMPLETED = "Completed"
    NO_ACTION = "No Action"


class Summary(UpdatedTimestampMixin, Base):
    """Optional structured AI summary for a transcript."""

    __tablename__ = "summaries"
    __table_args__ = (
        CheckConstraint(
            "mood IN ('Positive', 'Neutral', 'Negative') OR mood IS NULL",
            name="ck_summaries_mood",
        ),
        CheckConstraint(
            "action_status IN ('Pending', 'Completed', 'No Action') "
            "OR action_status IS NULL",
            name="ck_summaries_action_status",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    transcript_id: Mapped[int] = mapped_column(
        ForeignKey("transcripts.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    key_points: Mapped[list | None] = mapped_column(JSON)
    action_items: Mapped[list | None] = mapped_column(JSON)
    keywords: Mapped[list | None] = mapped_column(JSON)
    category: Mapped[str | None] = mapped_column(String(100), index=True)
    mood: Mapped[Mood | None] = mapped_column(
        SqlEnum(
            Mood,
            values_callable=lambda enum: [item.value for item in enum],
            name="mood",
            native_enum=False,
            create_constraint=False,
        )
    )
    action_status: Mapped[ActionStatus | None] = mapped_column(
        SqlEnum(
            ActionStatus,
            values_callable=lambda enum: [item.value for item in enum],
            name="action_status",
            native_enum=False,
            create_constraint=False,
        )
    )

    transcript: Mapped[Transcript] = relationship(back_populates="summary")
