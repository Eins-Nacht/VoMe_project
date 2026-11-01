"""add raw and corrected transcript fields

Revision ID: 0008_add_transcript_correction_fields
Revises: 0007_make_audio_path_temporary
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0008_add_transcript_correction_fields"
down_revision: Union[str, None] = "0007_make_audio_path_temporary"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("transcripts", sa.Column("raw_transcript", sa.Text(), nullable=True))
    op.add_column(
        "transcripts",
        sa.Column("corrected_transcript", sa.Text(), nullable=True),
    )
    op.execute(
        sa.text(
            "UPDATE transcripts SET raw_transcript = text "
            "WHERE raw_transcript IS NULL"
        )
    )


def downgrade() -> None:
    op.drop_column("transcripts", "corrected_transcript")
    op.drop_column("transcripts", "raw_transcript")
