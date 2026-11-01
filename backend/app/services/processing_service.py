from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from app.models import (
    AudioRecord,
    ProcessingJob,
    ProcessingStatus,
    Summary,
    Transcript,
    TranscriptionStatus,
)
from app.services.audio_storage_service import AudioStorageService
from app.services.processing_providers import (
    LlmProvider,
    MockLlmProvider,
    MockSttProvider,
    SttProvider,
)


class ProcessingService:
    def __init__(
        self,
        session_factory: sessionmaker,
        *,
        stt_provider: SttProvider | None = None,
        llm_provider: LlmProvider | None = None,
        storage_service: AudioStorageService | None = None,
    ) -> None:
        self.session_factory = session_factory
        self.stt_provider = stt_provider or MockSttProvider()
        self.llm_provider = llm_provider or MockLlmProvider()
        self.storage_service = storage_service or AudioStorageService()

    def run(self, job_id: int) -> None:
        with self.session_factory() as db:
            job = db.get(ProcessingJob, job_id)
            if job is None or job.status != ProcessingStatus.PENDING:
                return
            job.status = ProcessingStatus.PROCESSING
            job.transcription_status = None
            job.error_message = None
            db.commit()

            try:
                audio = db.get(AudioRecord, job.audio_record_id)
                if audio is None:
                    raise ValueError("Audio record no longer exists")
                audio_path = self.storage_service.resolve(audio.file_path)
                if not audio_path.is_file():
                    raise FileNotFoundError("Audio file is missing")
                transcript_result = self.stt_provider.transcribe(audio_path, audio.filename)
                if self._is_cancelled(db, job_id):
                    return
                job.transcription_status = transcript_result.status
                if transcript_result.status != TranscriptionStatus.SUCCESS:
                    job.status = ProcessingStatus.COMPLETED
                    job.error_message = transcript_result.message
                    db.commit()
                    return
                transcript = audio.transcript or Transcript(audio_record=audio)
                transcript.text = transcript_result.text
                transcript.language = transcript_result.language
                db.add(transcript)
                db.flush()
                db.commit()

                try:
                    summary_result = self.llm_provider.summarize(transcript_result)
                except Exception:
                    if self._is_cancelled(db, job_id):
                        return
                    job.status = ProcessingStatus.COMPLETED
                    job.transcription_status = TranscriptionStatus.SUCCESS
                    job.error_message = "Transcript completed; summary unavailable"
                    db.commit()
                    return

                if self._is_cancelled(db, job_id):
                    return
                summary = transcript.summary or Summary(transcript=transcript)
                summary.summary = summary_result.summary
                summary.key_points = summary_result.key_points
                summary.action_items = summary_result.action_items
                summary.keywords = summary_result.keywords
                summary.category = summary_result.category
                summary.mood = summary_result.mood
                summary.action_status = summary_result.action_status
                db.add(summary)
                job.status = ProcessingStatus.COMPLETED
                job.transcription_status = TranscriptionStatus.SUCCESS
                db.commit()
            except Exception as exc:
                db.rollback()
                failed_job = db.get(ProcessingJob, job_id)
                if failed_job is not None and not self._is_cancelled(db, job_id):
                    failed_job.status = ProcessingStatus.FAILED
                    failed_job.transcription_status = TranscriptionStatus.FAILED
                    failed_job.error_message = "Audio processing failed"
                    db.commit()

    def _is_cancelled(self, db: Session, job_id: int) -> bool:
        return (
            db.scalar(
                select(ProcessingJob.status).where(ProcessingJob.id == job_id)
            )
            == ProcessingStatus.CANCELLED
        )

    def mark_failed(self, job_id: int, error_message: str) -> None:
        with self.session_factory() as db:
            job = db.get(ProcessingJob, job_id)
            if job is not None and not self._is_cancelled(db, job_id):
                job.status = ProcessingStatus.FAILED
                job.transcription_status = TranscriptionStatus.FAILED
                job.error_message = error_message[:2000]
                db.commit()
