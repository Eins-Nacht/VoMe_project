"""add client recording id for idempotent uploads

Revision ID: 0004_add_client_recording_id
Revises: 0003_create_processing_jobs
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0004_add_client_recording_id"
down_revision: Union[str, None] = "0003_create_processing_jobs"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "audio_records",
        sa.Column("client_recording_id", sa.String(length=36), nullable=True),
    )
    op.create_index(
        "ix_audio_records_client_recording_id",
        "audio_records",
        ["client_recording_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_audio_records_client_recording_id",
        table_name="audio_records",
    )
    op.drop_column("audio_records", "client_recording_id")
