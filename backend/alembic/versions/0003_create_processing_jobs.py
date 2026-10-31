"""create processing jobs

Revision ID: 0003_create_processing_jobs
Revises: 0002_create_core_data
Create Date: 2026-10-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0003_create_processing_jobs"
down_revision: Union[str, None] = "0002_create_core_data"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "processing_jobs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("audio_record_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'processing', 'completed', 'failed')",
            name="ck_processing_jobs_status",
        ),
        sa.ForeignKeyConstraint(
            ["audio_record_id"], ["audio_records.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("audio_record_id"),
    )
    op.create_index(
        "ix_processing_jobs_audio_record_id",
        "processing_jobs",
        ["audio_record_id"],
        unique=False,
    )
    op.create_index(
        "ix_processing_jobs_status_updated_at",
        "processing_jobs",
        ["status", "updated_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_processing_jobs_status_updated_at", table_name="processing_jobs")
    op.drop_index("ix_processing_jobs_audio_record_id", table_name="processing_jobs")
    op.drop_table("processing_jobs")
