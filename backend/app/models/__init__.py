"""Core Audiary models and their relationship cardinality.

Users own many Events. Each Event owns many AudioRecords. An AudioRecord has
at most one optional Transcript, and a Transcript has at most one optional
Summary; processing creates the latter two records when results are ready.
Deleting an owner cascades to its dependent records, while audio binaries are
never stored in the database.
"""

from app.models.audio_record import AudioRecord
from app.models.event import Event
from app.models.processing_job import ProcessingJob, ProcessingStatus
from app.models.user import User
from app.models.summary import ActionStatus, Mood, Summary
from app.models.transcript import Transcript

__all__ = [
    "ActionStatus",
    "AudioRecord",
    "Event",
    "Mood",
    "ProcessingJob",
    "ProcessingStatus",
    "Summary",
    "Transcript",
    "User",
]
