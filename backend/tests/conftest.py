import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.infrastructure.database import get_db
from app.main import app
from app.models import ActionStatus, Mood
from app.models.base import Base
from app.services.processing_providers import (
    SummaryResult,
    TranscriptResult,
)


class TestSttProvider:
    def transcribe(self, audio_path, filename):
        return TranscriptResult(
            text=f"Test transcript for {filename}",
            language="en",
        )


class TestLlmProvider:
    def summarize(self, transcript):
        return SummaryResult(
            summary=f"Test summary: {transcript.text}",
            key_points=["Test processing completed"],
            action_items=[],
            keywords=["test", "audio"],
            category="General",
            mood=Mood.NEUTRAL,
            action_status=ActionStatus.NO_ACTION,
        )


class TestTranscriptCorrectionProvider:
    def correct(self, transcript):
        return transcript


@pytest.fixture
def client(tmp_path, monkeypatch):
    from app.core.config import get_settings
    import app.api.v1.processing as processing_api
    import app.services.processing_service as processing_service

    stt_provider = TestSttProvider()
    llm_provider = TestLlmProvider()
    correction_provider = TestTranscriptCorrectionProvider()
    monkeypatch.setattr(
        processing_api,
        "get_configured_stt_provider",
        lambda settings: stt_provider,
    )
    monkeypatch.setattr(
        processing_service,
        "get_configured_stt_provider",
        lambda settings: stt_provider,
    )
    monkeypatch.setattr(
        processing_service,
        "get_configured_transcript_correction_provider",
        lambda settings: correction_provider,
    )
    monkeypatch.setattr(
        processing_service,
        "get_configured_llm_provider",
        lambda settings: llm_provider,
    )
    monkeypatch.setattr(
        processing_api,
        "get_configured_providers",
        lambda settings: (stt_provider, llm_provider),
    )

    get_settings.cache_clear()
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}",
        connect_args={"check_same_thread": False},
    )
    testing_session = sessionmaker(
        bind=engine,
        autoflush=False,
        autocommit=False,
        expire_on_commit=False,
    )
    Base.metadata.create_all(engine)

    def override_get_db():
        db = testing_session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    app.state.testing_session = testing_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    del app.state.testing_session
    engine.dispose()
    get_settings.cache_clear()
