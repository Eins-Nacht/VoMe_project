from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.processing_job import ProcessingStage, ProcessingStatus, TranscriptionStatus
from app.schemas.audio import AudioRecordResponse


class ProcessingJobResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    audio_record_id: int
    status: ProcessingStatus
    transcription_status: TranscriptionStatus | None
    error_message: str | None
    processing_stage: ProcessingStage | None
    created_at: datetime
    updated_at: datetime


class ProcessingResultResponse(ProcessingJobResponse):
    audio: AudioRecordResponse
    event_title: str
    event_category: str | None
    transcript_text: str | None
    raw_transcript: str | None
    corrected_transcript: str | None
    transcript_language: str | None
    summary: str | None
    key_points: list | None
    action_items: list | None
    keywords: list | None
    category: str | None
    mood: str | None
    action_status: str | None
    message: str | None
