from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./audiary.db"
    audio_storage_dir: str = "./uploads/audio"
    max_audio_size_bytes: int = 50 * 1024 * 1024
    jwt_secret: str = "change-this-development-secret-use-at-least-32-bytes"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    llm_provider: str | None = None
    openai_api_key: str | None = None
    openai_summary_model: str = "gpt-4o-mini"
    ollama_base_url: str = "http://127.0.0.1:11434"
    ollama_model: str = "gemma3:latest"
    ollama_timeout_seconds: float = 30.0
    whisper_model: str = "Systran/faster-whisper-small"
    whisper_device: str = "cpu"
    whisper_compute_type: str = "int8"
    whisper_language: str | None = None
    whisper_model_dir: str | None = None
    temporary_audio_max_age_seconds: int = 24 * 60 * 60
    faster_whisper_model: str | None = None
    faster_whisper_compute_type: str | None = None

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
