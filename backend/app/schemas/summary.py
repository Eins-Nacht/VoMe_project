from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.summary import ActionStatus, Mood


class SummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    transcript_id: int
    audio_record_id: int
    client_recording_id: str | None = None
    event_id: int
    event_title: str
    audio_filename: str
    transcript_text: str | None
    transcript_language: str | None
    summary: str
    key_points: list[str] | None
    action_items: list[str] | None
    keywords: list[str] | None
    category: str | None
    mood: Mood | None
    action_status: ActionStatus | None
    created_at: datetime
    updated_at: datetime


class SummaryUpdate(BaseModel):
    summary: str | None = Field(default=None, min_length=1)
    key_points: list[str] | None = None
    action_items: list[str] | None = None
    keywords: list[str] | None = None
    category: str | None = Field(default=None, max_length=100)
    mood: Mood | None = None
    action_status: ActionStatus | None = None

    @field_validator("summary", "category")
    @classmethod
    def reject_blank_strings(cls, value: str | None) -> str | None:
        if value is not None and not value.strip():
            raise ValueError("value must not be blank")
        return value.strip() if value is not None else value

    @field_validator("key_points", "action_items", "keywords")
    @classmethod
    def validate_string_lists(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return value
        if any(not item.strip() for item in value):
            raise ValueError("list values must not be blank")
        return [item.strip() for item in value]


class SummaryListResponse(BaseModel):
    items: list[SummaryResponse]
    total: int
    limit: int
    offset: int
