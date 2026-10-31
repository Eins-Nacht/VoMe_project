from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Event, Lock
from types import SimpleNamespace

import pytest

from app.core.config import Settings
from app.services import processing_providers
from app.services.processing_providers import (
    MockLlmProvider,
    MockSttProvider,
    WhisperSttProvider,
    get_configured_providers,
)


def test_mock_provider_selection_is_explicit():
    stt, llm = get_configured_providers(Settings(processing_provider="mock"))

    assert isinstance(stt, MockSttProvider)
    assert isinstance(llm, MockLlmProvider)


def test_openai_provider_requires_api_key():
    with pytest.raises(
        RuntimeError,
        match="OPENAI_API_KEY is required when PROCESSING_PROVIDER=whisper_openai",
    ):
        get_configured_providers(
            Settings(processing_provider="whisper_openai", openai_api_key=None)
        )


def test_whisper_and_openai_providers_are_reused(monkeypatch):
    processing_providers._provider_cache.clear()
    settings = Settings(
        processing_provider="whisper_openai",
        openai_api_key="test-key",
    )

    first_stt, first_llm = get_configured_providers(settings)
    second_stt, second_llm = get_configured_providers(settings)

    assert first_stt is second_stt
    assert first_llm is second_llm
    assert isinstance(first_stt, WhisperSttProvider)


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
    key = (provider.model_name, provider.compute_type)
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
    with pytest.raises(RuntimeError, match="^Whisper transcription failed$"):
        provider.transcribe(Path("audio.wav"), "audio.wav")

    class EmptyModel:
        def transcribe(self, audio_path, vad_filter):
            return iter(()), SimpleNamespace(language="en")

    provider._get_model = lambda: EmptyModel()
    with pytest.raises(RuntimeError, match="^No speech was detected in this audio$"):
        provider.transcribe(Path("audio.wav"), "audio.wav")
