from dataclasses import dataclass
import json
from pathlib import Path
from threading import Lock, RLock
from typing import Protocol

from app.models import ActionStatus, Mood, TranscriptionStatus


@dataclass(frozen=True)
class TranscriptResult:
    text: str | None
    language: str | None
    status: TranscriptionStatus = TranscriptionStatus.SUCCESS
    message: str | None = None


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
    _model_cache: dict[tuple[str, str, str, str | None], object] = {}
    _model_cache_lock = Lock()

    def __init__(
        self,
        model_name: str,
        compute_type: str = "int8",
        device: str = "cpu",
        language: str | None = None,
        model_dir: str | None = None,
    ) -> None:
        self.model_name = model_name
        self.device = device
        self.compute_type = compute_type
        self.language = language
        self.model_dir = model_dir
        self._transcribe_lock = Lock()

    def _get_model(self):
        key = (
            self.model_name,
            self.device,
            self.compute_type,
            self.model_dir or None,
        )
        model = self._model_cache.get(key)
        if model is not None:
            return model
        with self._model_cache_lock:
            model = self._model_cache.get(key)
            if model is None:
                from faster_whisper import WhisperModel

                model = WhisperModel(
                    self.model_name,
                    device=self.device,
                    compute_type=self.compute_type,
                    **({"download_root": self.model_dir} if self.model_dir else {}),
                )
                self._model_cache[key] = model
        return model

    def _validate_audio(self, audio_path: Path) -> str | None:
        if not audio_path.exists():
            return "The audio file is missing or invalid"
        if audio_path.stat().st_size == 0:
            return "The audio file is empty or invalid"
        try:
            import av

            with av.open(str(audio_path)) as container:
                audio_streams = [
                    stream for stream in container.streams if stream.type == "audio"
                ]
                if not audio_streams:
                    return "The audio file is empty or invalid"
                durations = [
                    stream.duration * float(stream.time_base)
                    for stream in audio_streams
                    if stream.duration is not None and stream.time_base is not None
                ]
                if durations and max(durations) <= 0:
                    return "The audio file is empty or invalid"
        except Exception:
            return "The audio file is empty or invalid"
        return None

    def transcribe(self, audio_path: Path, filename: str) -> TranscriptResult:
        with self._transcribe_lock:
            try:
                validation_error = self._validate_audio(audio_path)
            except OSError:
                validation_error = "The audio file is empty or invalid"
            if validation_error:
                return TranscriptResult(
                    text=None,
                    language=None,
                    status=TranscriptionStatus.INVALID_AUDIO,
                    message=validation_error,
                )
            try:
                segments, info = self._get_model().transcribe(
                    str(audio_path),
                    vad_filter=True,
                    **({"language": self.language} if self.language else {}),
                )
                collected_segments = list(segments)
            except Exception:
                raise RuntimeError(
                    "Whisper model initialization or transcription failed"
                ) from None
            text = " ".join(
                segment.text.strip() for segment in collected_segments
            ).strip()
            if not text:
                return TranscriptResult(
                    text=None,
                    language=getattr(info, "language", None),
                    status=TranscriptionStatus.NO_SPEECH,
                    message="No speech detected in audio",
                )
            # Require all three indicators before rejecting speech as unclear;
            # this preserves short utterances and tolerates isolated noise.
            low_quality = [
                segment
                for segment in collected_segments
                if getattr(segment, "no_speech_prob", 0) >= 0.85
                and getattr(segment, "avg_logprob", 0) <= -1.5
                and getattr(segment, "compression_ratio", 0) >= 2.4
            ]
            if len(low_quality) == len(collected_segments):
                return TranscriptResult(
                    text=None,
                    language=getattr(info, "language", None),
                    status=TranscriptionStatus.UNCLEAR_SPEECH,
                    message="Speech was detected but could not be transcribed reliably",
                )
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


_provider_cache: dict[tuple[object, ...], tuple[SttProvider, LlmProvider]] = {}
_stt_provider_cache: dict[tuple[object, ...], SttProvider] = {}
_provider_cache_lock = RLock()


def get_configured_stt_provider(settings) -> SttProvider:
    stt_name = settings.effective_stt_provider
    key = (
        stt_name,
        settings.effective_whisper_model,
        settings.whisper_device,
        settings.effective_whisper_compute_type,
        settings.whisper_language or None,
        settings.whisper_model_dir or None,
    )
    provider = _stt_provider_cache.get(key)
    if provider is None:
        with _provider_cache_lock:
            provider = _stt_provider_cache.get(key)
            if provider is None:
                provider = (
                    WhisperSttProvider(
                        model_name=settings.effective_whisper_model,
                        device=settings.whisper_device,
                        compute_type=settings.effective_whisper_compute_type,
                        language=settings.whisper_language or None,
                        model_dir=settings.whisper_model_dir or None,
                    )
                    if stt_name == "faster_whisper"
                    else MockSttProvider()
                )
                _stt_provider_cache[key] = provider
    return provider


def get_configured_providers(settings) -> tuple[SttProvider, LlmProvider]:
    stt_name = settings.effective_stt_provider
    llm_name = settings.effective_llm_provider
    if llm_name == "openai" and not settings.openai_api_key:
        raise RuntimeError(
            "OPENAI_API_KEY is required when LLM_PROVIDER=openai "
            "or PROCESSING_PROVIDER=whisper_openai"
        )

    key = (
        stt_name,
        llm_name,
        settings.effective_whisper_model,
        settings.whisper_device,
        settings.effective_whisper_compute_type,
        settings.whisper_language or None,
        settings.whisper_model_dir or None,
        settings.openai_api_key,
        settings.openai_summary_model,
    )
    providers = _provider_cache.get(key)
    if providers is None:
        with _provider_cache_lock:
            providers = _provider_cache.get(key)
            if providers is None:
                stt_provider = get_configured_stt_provider(settings)
                llm_provider: LlmProvider = (
                    OpenAILlmProvider(
                        settings.openai_api_key,
                        settings.openai_summary_model,
                    )
                    if llm_name == "openai"
                    else MockLlmProvider()
                )
                providers = (
                    stt_provider,
                    llm_provider,
                )
                _provider_cache[key] = providers
    return providers
