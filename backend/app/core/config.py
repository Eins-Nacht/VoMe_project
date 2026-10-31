from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./audiary.db"
    audio_storage_dir: str = "./uploads/audio"
    max_audio_size_bytes: int = 50 * 1024 * 1024
    jwt_secret: str = "change-this-development-secret-use-at-least-32-bytes"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    processing_provider: Literal["mock", "whisper_openai"] = "mock"
    openai_api_key: str | None = None
    openai_summary_model: str = "gpt-4o-mini"
    faster_whisper_model: str = "small"
    faster_whisper_compute_type: str = "int8"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
