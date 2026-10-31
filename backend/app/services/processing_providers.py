from dataclasses import dataclass
import json
from pathlib import Path
from threading import Lock
from typing import Protocol

from app.models import ActionStatus, Mood


@dataclass(frozen=True)
class TranscriptResult:
    text: str
    language: str | None


@dataclass(frozen=True)
class SummaryResult:
    summary: str
    key_points: list[str]
    action_items: list[str]
    keywords: list[str]
    category: str
    mood: Mood
    action_status: ActionStatus


class SttProvider(Protocol):
    def transcribe(self, audio_path: Path, filename: str) -> TranscriptResult:
        ...


class LlmProvider(Protocol):
    def summarize(self, transcript: TranscriptResult) -> SummaryResult:
        ...


class MockSttProvider:
    def transcribe(self, audio_path: Path, filename: str) -> TranscriptResult:
        return TranscriptResult(
            text=f"Mock transcript for {filename}",
            language="en",
        )


class MockLlmProvider:
    def summarize(self, transcript: TranscriptResult) -> SummaryResult:
        return SummaryResult(
            summary=f"Mock summary: {transcript.text}",
            key_points=["Mock processing completed"],
            action_items=[],
            keywords=["mock", "audio"],
            category="General",
            mood=Mood.NEUTRAL,
            action_status=ActionStatus.NO_ACTION,
        )


class WhisperSttProvider:
    _model_cache: dict[tuple[str, str], object] = {}
    _model_cache_lock = Lock()

    def __init__(self, model_name: str, compute_type: str) -> None:
        self.model_name = model_name
        self.compute_type = compute_type
        self._transcribe_lock = Lock()

    def _get_model(self):
        key = (self.model_name, self.compute_type)
        model = self._model_cache.get(key)
        if model is not None:
            return model
        with self._model_cache_lock:
            model = self._model_cache.get(key)
            if model is None:
                from faster_whisper import WhisperModel

                model = WhisperModel(
                    self.model_name,
                    device="cpu",
                    compute_type=self.compute_type,
                )
                self._model_cache[key] = model
        return model

    def transcribe(self, audio_path: Path, filename: str) -> TranscriptResult:
        with self._transcribe_lock:
            try:
                segments, info = self._get_model().transcribe(
                    str(audio_path),
                    vad_filter=True,
                )
                text = " ".join(
                    segment.text.strip() for segment in segments
                ).strip()
            except Exception:
                raise RuntimeError("Whisper transcription failed") from None
            if not text:
                raise RuntimeError("No speech was detected in this audio")
            return TranscriptResult(
                text=text,
                language=getattr(info, "language", None),
            )


class OpenAILlmProvider:
    def __init__(self, api_key: str, model_name: str) -> None:
        self.api_key = api_key
        self.model_name = model_name
        self._client = None
        self._client_lock = Lock()

    def summarize(self, transcript: TranscriptResult) -> SummaryResult:
        try:
            from openai import OpenAI

            if self._client is None:
                with self._client_lock:
                    if self._client is None:
                        self._client = OpenAI(api_key=self.api_key)
            response = self._client.responses.create(
                model=self.model_name,
                input=[
                    {
                        "role": "system",
                        "content": "Summarize the transcript faithfully. Do not invent facts.",
                    },
                    {"role": "user", "content": transcript.text},
                ],
                text={
                    "format": {
                        "type": "json_schema",
                        "name": "audiary_summary",
                        "strict": True,
                        "schema": {
                            "type": "object",
                            "additionalProperties": False,
                            "properties": {
                                "summary": {"type": "string"},
                                "key_points": {"type": "array", "items": {"type": "string"}},
                                "action_items": {"type": "array", "items": {"type": "string"}},
                                "keywords": {"type": "array", "items": {"type": "string"}},
                                "category": {"type": "string"},
                                "mood": {"type": "string", "enum": [m.value for m in Mood]},
                                "action_status": {
                                    "type": "string",
                                    "enum": [status.value for status in ActionStatus],
                                },
                            },
                            "required": [
                                "summary",
                                "key_points",
                                "action_items",
                                "keywords",
                                "category",
                                "mood",
                                "action_status",
                            ],
                        },
                    }
                },
            )
            data = json.loads(response.output_text)
        except Exception:
            raise RuntimeError("OpenAI summarization failed") from None
        return SummaryResult(
            summary=data["summary"],
            key_points=data["key_points"],
            action_items=data["action_items"],
            keywords=data["keywords"],
            category=data["category"],
            mood=Mood(data["mood"]),
            action_status=ActionStatus(data["action_status"]),
        )


_provider_cache: dict[tuple[str, str, str], tuple[WhisperSttProvider, OpenAILlmProvider]] = {}
_provider_cache_lock = Lock()


def get_configured_providers(settings) -> tuple[SttProvider, LlmProvider]:
    if settings.processing_provider == "mock":
        return MockSttProvider(), MockLlmProvider()
    if settings.processing_provider != "whisper_openai":
        raise RuntimeError("Unsupported processing provider configuration")
    if not settings.openai_api_key:
        raise RuntimeError(
            "OPENAI_API_KEY is required when PROCESSING_PROVIDER=whisper_openai"
        )

    key = (
        settings.faster_whisper_model,
        settings.faster_whisper_compute_type,
        settings.openai_summary_model,
    )
    providers = _provider_cache.get(key)
    if providers is None:
        with _provider_cache_lock:
            providers = _provider_cache.get(key)
            if providers is None:
                providers = (
                    WhisperSttProvider(
                        settings.faster_whisper_model,
                        settings.faster_whisper_compute_type,
                    ),
                    OpenAILlmProvider(
                        settings.openai_api_key,
                        settings.openai_summary_model,
                    ),
                )
                _provider_cache[key] = providers
    return providers
