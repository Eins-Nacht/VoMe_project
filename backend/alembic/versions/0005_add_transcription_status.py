"""add transcription outcome to processing jobs

Revision ID: 0005_add_transcription_status
Revises: 0004_add_client_recording_id
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0005_add_transcription_status"
down_revision: Union[str, None] = "0004_add_client_recording_id"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "processing_jobs",
        sa.Column("transcription_status", sa.String(length=20), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("processing_jobs", "transcription_status")
