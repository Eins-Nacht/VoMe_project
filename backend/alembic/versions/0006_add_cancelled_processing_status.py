"""allow processing jobs to be cancelled

Revision ID: 0006_add_cancelled_processing_status
Revises: 0005_add_transcription_status
"""
from typing import Sequence, Union

from alembic import op


revision: str = "0006_add_cancelled_processing_status"
down_revision: Union[str, None] = "0005_add_transcription_status"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("processing_jobs") as batch_op:
        batch_op.drop_constraint("ck_processing_jobs_status", type_="check")
        batch_op.create_check_constraint(
            "ck_processing_jobs_status",
            "status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')",
        )


def downgrade() -> None:
    with op.batch_alter_table("processing_jobs") as batch_op:
        batch_op.drop_constraint("ck_processing_jobs_status", type_="check")
        batch_op.create_check_constraint(
            "ck_processing_jobs_status",
            "status IN ('pending', 'processing', 'completed', 'failed')",
        )
