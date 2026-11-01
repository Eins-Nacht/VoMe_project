from datetime import datetime

from pydantic import BaseModel, ConfigDict


class AudioRecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    event_id: int
    filename: str
    format: str
    size: int
    duration: float | None
    audio_path: str | None
    created_at: datetime
    updated_at: datetime
    client_recording_id: str | None = None
