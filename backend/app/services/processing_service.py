from contextlib import nullcontext

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings
import logging
from pathlib import Path

from app.models import (
    AudioRecord,
    ProcessingJob,
    ProcessingStatus,
    ProcessingStage,
    Summary,
    Transcript,
    TranscriptionStatus,
)
from app.services.audio_storage_service import AudioStorageService
from app.services.processing_providers import (
    LlmProvider,
    SttProvider,
    TranscriptResult,
    TranscriptCorrectionProvider,
    get_configured_transcript_correction_provider,
    get_configured_llm_provider,
    get_configured_stt_provider,
)

logger = logging.getLogger(__name__)


class ProcessingService:
    def __init__(
        self,
        session_factory: sessionmaker,
        *,
        stt_provider: SttProvider | None = None,
        llm_provider: LlmProvider | None = None,
        correction_provider: TranscriptCorrectionProvider | None = None,
        storage_service: AudioStorageService | None = None,
    ) -> None:
        self.session_factory = session_factory
        self.stt_provider = stt_provider or get_configured_stt_provider(
            get_settings()
        )
        self.llm_provider = llm_provider
        self.correction_provider = correction_provider
        self.storage_service = storage_service or AudioStorageService()

    def run(self, job_id: int) -> None:
        self.run_transcription(job_id)

    def run_transcription(self, job_id: int) -> None:
        audio_path = None
        with self.session_factory() as db:
            job = db.get(ProcessingJob, job_id)
            if job is None or job.status != ProcessingStatus.PENDING:
                return
            job.status = ProcessingStatus.PROCESSING
            job.processing_stage = ProcessingStage.TRANSCRIBING
            job.transcription_status = None
            job.error_message = None
            db.commit()

            try:
                audio = db.get(AudioRecord, job.audio_record_id)
                if audio is None:
                    raise ValueError("Audio record no longer exists")
                if audio.file_path is None:
                    raise FileNotFoundError("Temporary audio file is missing")
                audio_path = self.storage_service.resolve(audio.file_path)
                if not audio_path.is_file():
                    raise FileNotFoundError("Audio file is missing")
                transcript_result = self.stt_provider.transcribe(audio_path, audio.filename)
                if self._is_cancelled(db, job_id):
                    return
                job.transcription_status = transcript_result.status
                if transcript_result.status != TranscriptionStatus.SUCCESS:
                    job.status = ProcessingStatus.FAILED
                    job.processing_stage = ProcessingStage.FAILED
                    job.error_message = transcript_result.message
                    db.commit()
                    return
                transcript = audio.transcript or Transcript(audio_record=audio)
                transcript.text = transcript_result.text
                transcript.raw_transcript = transcript_result.text
                transcript.corrected_transcript = None
                transcript.language = transcript_result.language
                db.add(transcript)
                db.flush()
                db.commit()
                job.processing_stage = ProcessingStage.CORRECTING
                db.commit()
                try:
                    correction_provider = (
                        self.correction_provider
                        or get_configured_transcript_correction_provider(
                            get_settings()
                        )
                    )
                    corrected = correction_provider.correct(transcript_result.text)
                    transcript.corrected_transcript = corrected
                    db.commit()
                except Exception:
                    logger.warning(
                        "Transcript correction failed for job %s; keeping raw transcript",
                        job_id,
                        exc_info=True,
                    )
                job.processing_stage = ProcessingStage.SUMMARIZING
                db.commit()
                if transcript.summary is None:
                    if self.llm_provider is None:
                        self.llm_provider = get_configured_llm_provider(get_settings())
                    summary_result = self.llm_provider.summarize(
                        TranscriptResult(
                            text=transcript.corrected_transcript
                            or transcript.raw_transcript
                            or transcript.text,
                            language=transcript.language,
                        )
                    )
                    db.add(
                        Summary(
                            transcript=transcript,
                            summary=summary_result.summary,
                            key_points=summary_result.key_points,
                            action_items=summary_result.action_items,
                            keywords=summary_result.keywords,
                            category=summary_result.category,
                            mood=summary_result.mood,
                            action_status=summary_result.action_status,
                        )
                    )
                    db.commit()
                if audio_path is not None:
                    self._cleanup_temporary_audio(
                        job.audio_record_id,
                        job_id,
                        audio_path,
                    )
                    audio_path = None
                job.status = ProcessingStatus.COMPLETED
                job.processing_stage = ProcessingStage.COMPLETED
                job.transcription_status = TranscriptionStatus.SUCCESS
                db.commit()
            except Exception as exc:
                db.rollback()
                failed_job = db.get(ProcessingJob, job_id)
                if failed_job is not None and not self._is_cancelled(db, job_id):
                    failed_job.status = ProcessingStatus.FAILED
                    failed_job.processing_stage = ProcessingStage.FAILED
                    failed_job.transcription_status = TranscriptionStatus.FAILED
                    failed_job.error_message = str(exc)[:2000] or "Audio processing failed"
                    db.commit()
            finally:
                if audio_path is not None:
                    self._cleanup_temporary_audio(
                        job.audio_record_id,
                        job_id,
                        audio_path,
                    )

    def generate_summary(self, job_id: int) -> Summary:
        with self.session_factory() as db:
            job = db.get(ProcessingJob, job_id)
            if job is None:
                raise ValueError("Processing job not found")
            if job.status != ProcessingStatus.COMPLETED:
                raise ValueError("Transcription has not completed")
            transcript = db.scalar(
                select(Transcript).where(
                    Transcript.audio_record_id == job.audio_record_id
                )
            )
            if transcript is None or not transcript.text.strip():
                raise ValueError("A non-empty transcript is required")
            if transcript.summary is not None:
                return transcript.summary

            if self.llm_provider is None:
                self.llm_provider = get_configured_llm_provider(get_settings())
            summary_result = self.llm_provider.summarize(
                TranscriptResult(
                    text=(
                        transcript.corrected_transcript
                        or transcript.raw_transcript
                        or transcript.text
                    ),
                    language=transcript.language,
                )
            )
            summary = Summary(
                transcript=transcript,
                summary=summary_result.summary,
                key_points=summary_result.key_points,
                action_items=summary_result.action_items,
                keywords=summary_result.keywords,
                category=summary_result.category,
                mood=summary_result.mood,
                action_status=summary_result.action_status,
            )
            db.add(summary)
            try:
                db.commit()
            except IntegrityError:
                db.rollback()
                existing = db.scalar(
                    select(Summary).where(
                        Summary.transcript_id == transcript.id
                    )
                )
                if existing is None:
                    raise
                return existing
            db.refresh(summary)
            return summary

    def regenerate_summary(self, summary_id: int, db: Session | None = None) -> Summary:
        with (
            nullcontext(db)
            if db is not None
            else self.session_factory()
        ) as db:
            summary = db.get(Summary, summary_id)
            if summary is None:
                raise ValueError("Summary not found")
            transcript = db.get(Transcript, summary.transcript_id)
            if transcript is None:
                raise ValueError("Transcript not found")
            text = (
                transcript.corrected_transcript
                or transcript.raw_transcript
                or transcript.text
            )
            if not text or not text.strip():
                raise ValueError("A non-empty transcript is required")
            if self.llm_provider is None:
                self.llm_provider = get_configured_llm_provider(get_settings())
            result = self.llm_provider.summarize(
                TranscriptResult(text=text, language=transcript.language)
            )
            summary.summary = result.summary
            summary.key_points = result.key_points
            summary.action_items = result.action_items
            summary.keywords = result.keywords
            summary.category = result.category
            summary.mood = result.mood
            summary.action_status = result.action_status
            db.commit()
            db.refresh(summary)
            return summary

    def _cleanup_temporary_audio(
        self,
        audio_record_id: int,
        job_id: int,
        audio_path: Path,
    ) -> None:
        try:
            audio_path.unlink(missing_ok=True)
        except OSError:
            logger.warning(
                "Could not remove temporary audio for job %s",
                job_id,
                exc_info=True,
            )
            return

        cleanup = self.session_factory()
        try:
            audio = cleanup.get(AudioRecord, audio_record_id)
            if audio is not None:
                audio.file_path = None
                cleanup.commit()
        except Exception:
            cleanup.rollback()
            logger.warning(
                "Could not clear temporary audio reference for job %s",
                job_id,
                exc_info=True,
            )
        finally:
            cleanup.close()

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
                job.processing_stage = ProcessingStage.FAILED
                job.transcription_status = TranscriptionStatus.FAILED
                job.error_message = error_message[:2000]
                db.commit()
