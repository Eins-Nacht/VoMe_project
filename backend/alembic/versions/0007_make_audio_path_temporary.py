"""allow audio metadata to outlive temporary backend files

Revision ID: 0007_make_audio_path_temporary
Revises: 0006_add_cancelled_processing_status
"""
from typing import Sequence, Union

from alembic import op


revision: str = "0007_make_audio_path_temporary"
down_revision: Union[str, None] = "0006_add_cancelled_processing_status"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("audio_records") as batch_op:
        batch_op.alter_column("file_path", nullable=True)


def downgrade() -> None:
    with op.batch_alter_table("audio_records") as batch_op:
        batch_op.alter_column("file_path", nullable=False)
