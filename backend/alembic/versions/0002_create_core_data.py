"""create core Audiary data tables

Revision ID: 0002_create_core_data
Revises: 0001_create_users
Create Date: 2026-10-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0002_create_core_data"
down_revision: Union[str, None] = "0001_create_users"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("category", sa.String(length=100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_events_user_id", "events", ["user_id"], unique=False)
    op.create_index("ix_events_user_id_created_at", "events", ["user_id", "created_at"], unique=False)
    op.create_index("ix_events_category", "events", ["category"], unique=False)

    op.create_table(
        "audio_records",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("event_id", sa.Integer(), nullable=False),
        sa.Column("filename", sa.String(length=255), nullable=False),
        sa.Column("file_path", sa.String(length=1024), nullable=False),
        sa.Column("format", sa.String(length=20), nullable=False),
        sa.Column("size", sa.Integer(), nullable=False),
        sa.Column("duration", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.CheckConstraint("size >= 0", name="ck_audio_records_size_nonnegative"),
        sa.CheckConstraint("duration IS NULL OR duration >= 0", name="ck_audio_records_duration_nonnegative"),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("file_path"),
    )
    op.create_index("ix_audio_records_event_id", "audio_records", ["event_id"], unique=False)
    op.create_index("ix_audio_records_event_id_created_at", "audio_records", ["event_id", "created_at"], unique=False)

    op.create_table(
        "transcripts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("audio_record_id", sa.Integer(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("language", sa.String(length=20), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.ForeignKeyConstraint(["audio_record_id"], ["audio_records.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("audio_record_id"),
    )
    op.create_index("ix_transcripts_audio_record_id", "transcripts", ["audio_record_id"], unique=False)

    op.create_table(
        "summaries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("transcript_id", sa.Integer(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("key_points", sa.JSON(), nullable=True),
        sa.Column("action_items", sa.JSON(), nullable=True),
        sa.Column("keywords", sa.JSON(), nullable=True),
        sa.Column("category", sa.String(length=100), nullable=True),
        sa.Column("mood", sa.String(length=8), nullable=True),
        sa.Column("action_status", sa.String(length=9), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.CheckConstraint("mood IN ('Positive', 'Neutral', 'Negative') OR mood IS NULL", name="ck_summaries_mood"),
        sa.CheckConstraint("action_status IN ('Pending', 'Completed', 'No Action') OR action_status IS NULL", name="ck_summaries_action_status"),
        sa.ForeignKeyConstraint(["transcript_id"], ["transcripts.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("transcript_id"),
    )
    op.create_index("ix_summaries_transcript_id", "summaries", ["transcript_id"], unique=False)
    op.create_index("ix_summaries_category", "summaries", ["category"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_summaries_category", table_name="summaries")
    op.drop_index("ix_summaries_transcript_id", table_name="summaries")
    op.drop_table("summaries")

    op.drop_index("ix_transcripts_audio_record_id", table_name="transcripts")
    op.drop_table("transcripts")

    op.drop_index("ix_audio_records_event_id_created_at", table_name="audio_records")
    op.drop_index("ix_audio_records_event_id", table_name="audio_records")
    op.drop_table("audio_records")

    op.drop_index("ix_events_category", table_name="events")
    op.drop_index("ix_events_user_id_created_at", table_name="events")
    op.drop_index("ix_events_user_id", table_name="events")
    op.drop_table("events")
