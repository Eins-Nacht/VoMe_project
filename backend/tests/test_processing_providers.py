from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Event, Lock
from types import SimpleNamespace

import pytest

from app.core.config import Settings
from app.services import processing_providers
from app.services.processing_providers import (
    WhisperSttProvider,
    get_configured_providers,
)


def test_openai_provider_requires_api_key():
    with pytest.raises(
        RuntimeError,
        match="OPENAI_API_KEY is required",
    ):
        get_configured_providers(
            Settings(llm_provider="openai", openai_api_key=None)
        )


def test_faster_whisper_requires_a_real_llm_provider_for_summaries():
    with pytest.raises(
        RuntimeError,
        match="LLM_PROVIDER must be configured",
    ):
        get_configured_providers(
            Settings(
                _env_file=None,
                openai_api_key=None,
            )
        )


def test_faster_whisper_is_the_only_stt_provider():
    settings = Settings()

    assert settings.effective_whisper_model == "Systran/faster-whisper-small"
    assert isinstance(
        processing_providers.get_configured_stt_provider(settings),
        WhisperSttProvider,
    )


def test_whisper_and_openai_providers_are_reused(monkeypatch):
    settings = Settings(
        llm_provider="openai",
        openai_api_key="test-key",
    )

    first_stt, first_llm = get_configured_providers(settings)
    second_stt, second_llm = get_configured_providers(settings)

    assert first_stt is second_stt
    assert first_llm is second_llm
    assert isinstance(first_stt, WhisperSttProvider)


def test_whisper_configuration_is_forwarded_and_language_is_optional():
    provider = WhisperSttProvider(
        "test",
        device="cpu",
        compute_type="int8",
        language="th",
        model_dir="/models",
    )
    calls = []

    class FakeModel:
        def transcribe(self, audio_path, **kwargs):
            calls.append(kwargs)
            return iter([SimpleNamespace(text="สวัสดี")]), SimpleNamespace(language="th")

    provider._get_model = lambda: FakeModel()
    provider._validate_audio = lambda _: None

    result = provider.transcribe(Path("audio.wav"), "audio.wav")

    assert result.text == "สวัสดี"
    assert calls == [{"vad_filter": True, "language": "th"}]


def test_whisper_uses_automatic_language_detection_when_unset():
    provider = WhisperSttProvider("test", language=None)
    calls = []

    class FakeModel:
        def transcribe(self, audio_path, **kwargs):
            calls.append(kwargs)
            return iter([SimpleNamespace(text="hello")]), SimpleNamespace(language="en")

    provider._get_model = lambda: FakeModel()
    provider._validate_audio = lambda _: None

    result = provider.transcribe(Path("audio.wav"), "audio.wav")

    assert result.language == "en"
    assert calls == [{"vad_filter": True}]


def test_whisper_consumes_segments_while_transcription_lock_is_held():
    provider = WhisperSttProvider("test", "int8")
    lock_observed = []

    def segments():
        lock_observed.append(provider._transcribe_lock.acquire(blocking=False))
        if lock_observed[-1]:
            provider._transcribe_lock.release()
        yield SimpleNamespace(text="hello")

    class FakeModel:
        def transcribe(self, audio_path, vad_filter):
            return segments(), SimpleNamespace(language="en")

    provider._get_model = lambda: FakeModel()
    provider._validate_audio = lambda _: None

    result = provider.transcribe(Path("audio.wav"), "audio.wav")

    assert result.text == "hello"
    assert lock_observed == [False]


def test_whisper_calls_are_serialized_for_one_provider():
    provider = WhisperSttProvider("test", "int8")
    inference_started = Event()
    release_inference = Event()
    active_calls = 0
    max_active_calls = 0
    active_lock = Lock()

    def make_segments():
        nonlocal active_calls, max_active_calls
        with active_lock:
            active_calls += 1
            max_active_calls = max(max_active_calls, active_calls)
        inference_started.set()
        release_inference.wait(timeout=2)
        with active_lock:
            active_calls -= 1
        yield SimpleNamespace(text="serialized")

    class FakeModel:
        def transcribe(self, audio_path, vad_filter):
            return make_segments(), SimpleNamespace(language="en")

    provider._get_model = lambda: FakeModel()
    provider._validate_audio = lambda _: None

    with ThreadPoolExecutor(max_workers=2) as executor:
        first = executor.submit(
            provider.transcribe,
            Path("one.wav"),
            "one.wav",
        )
        assert inference_started.wait(timeout=2)
        second = executor.submit(
            provider.transcribe,
            Path("two.wav"),
            "two.wav",
        )
        release_inference.set()
        assert first.result().text == "serialized"
        assert second.result().text == "serialized"

    assert max_active_calls == 1


def test_whisper_model_cache_reuses_model_instance():
    provider = WhisperSttProvider("test", "int8")
    fake_model = object()
    key = (provider.model_name, provider.device, provider.compute_type, None)
    original_cache = WhisperSttProvider._model_cache
    WhisperSttProvider._model_cache = {key: fake_model}
    try:
        assert provider._get_model() is fake_model
        assert provider._get_model() is fake_model
    finally:
        WhisperSttProvider._model_cache = original_cache


def test_whisper_errors_are_sanitized_and_empty_transcripts_are_rejected():
    provider = WhisperSttProvider("test", "int8")

    class FailingModel:
        def transcribe(self, audio_path, vad_filter):
            raise RuntimeError("secret provider internals")

    provider._get_model = lambda: FailingModel()
    provider._validate_audio = lambda _: None
    with pytest.raises(
        RuntimeError,
        match="^Whisper model initialization or transcription failed$",
    ):
        provider.transcribe(Path("audio.wav"), "audio.wav")

    class EmptyModel:
        def transcribe(self, audio_path, vad_filter):
            return iter(()), SimpleNamespace(language="en")

    provider._get_model = lambda: EmptyModel()
    provider._validate_audio = lambda _: None
    result = provider.transcribe(Path("audio.wav"), "audio.wav")
    assert result.status.value == "no_speech"
    assert result.text is None


def test_whisper_rejects_empty_and_invalid_audio(tmp_path):
    provider = WhisperSttProvider("test", "int8")

    empty = tmp_path / "empty.wav"
    empty.write_bytes(b"")
    result = provider.transcribe(empty, empty.name)
    assert result.status.value == "invalid_audio"
    assert result.message == "The audio file is empty or invalid"

    invalid = tmp_path / "invalid.wav"
    invalid.write_bytes(b"not audio")
    result = provider.transcribe(invalid, invalid.name)
    assert result.status.value == "invalid_audio"

    missing = tmp_path / "missing.wav"
    result = provider.transcribe(missing, missing.name)
    assert result.status.value == "invalid_audio"
    assert result.message == "The audio file is missing or invalid"


def test_whisper_classifies_all_low_quality_segments_as_unclear():
    provider = WhisperSttProvider("test", "int8")
    audio = Path("audio.wav")

    class FakeModel:
        def transcribe(self, audio_path, vad_filter):
            return iter(
                [
                    SimpleNamespace(
                        text="garbled",
                        no_speech_prob=0.9,
                        avg_logprob=-2.0,
                        compression_ratio=3.0,
                    )
                ]
            ), SimpleNamespace(language="en")

    provider._get_model = lambda: FakeModel()
    provider._validate_audio = lambda _: None
    result = provider.transcribe(audio, audio.name)
    assert result.status.value == "unclear_speech"
