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
    stt_provider: Literal["mock", "faster_whisper"] | None = None
    llm_provider: Literal["mock", "openai"] | None = None
    openai_api_key: str | None = None
    openai_summary_model: str = "gpt-4o-mini"
    whisper_model: str = "small"
    whisper_device: str = "cpu"
    whisper_compute_type: str = "int8"
    whisper_language: str | None = None
    whisper_model_dir: str | None = None
    faster_whisper_model: str | None = None
    faster_whisper_compute_type: str | None = None

    @property
    def effective_stt_provider(self) -> Literal["mock", "faster_whisper"]:
        if self.stt_provider is not None:
            return self.stt_provider
        return "faster_whisper" if self.processing_provider == "whisper_openai" else "mock"

    @property
    def effective_llm_provider(self) -> Literal["mock", "openai"]:
        if self.llm_provider is not None:
            return self.llm_provider
        return "openai" if self.processing_provider == "whisper_openai" else "mock"

    @property
    def effective_whisper_model(self) -> str:
        return self.faster_whisper_model or self.whisper_model

    @property
    def effective_whisper_compute_type(self) -> str:
        return self.faster_whisper_compute_type or self.whisper_compute_type

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_ignore_empty=True,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
