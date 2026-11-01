"""add processing stage

Revision ID: 0009_add_processing_stage
Revises: 0008_add_transcript_correction_fields
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0009_add_processing_stage"
down_revision: Union[str, None] = "0008_add_transcript_correction_fields"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "processing_jobs",
        sa.Column("processing_stage", sa.String(length=20), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("processing_jobs", "processing_stage")
