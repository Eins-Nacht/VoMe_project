from dataclasses import dataclass
from pathlib import Path
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
