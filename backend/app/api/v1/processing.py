from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.api.v1.audio import _response as audio_response, storage
from app.api.v1.auth import get_current_user
from app.infrastructure.database import SessionLocal, get_db
from app.models import AudioRecord, Event, ProcessingJob, ProcessingStatus, User
from app.models.transcript import Transcript
from app.schemas.processing import ProcessingJobResponse, ProcessingResultResponse
from app.services.audio_storage_service import AudioStorageError
from app.services.processing_service import ProcessingService
from app.core.config import get_settings
from app.services.processing_providers import (
    get_configured_providers,
    get_configured_stt_provider,
)

router = APIRouter(prefix="/processing", tags=["processing"])


def _owned_job(db: Session, user: User, job_id: int) -> ProcessingJob:
    job = db.scalar(
        select(ProcessingJob)
        .join(ProcessingJob.audio_record)
        .join(AudioRecord.event)
        .where(ProcessingJob.id == job_id, Event.user_id == user.id)
    )
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Processing job not found",
        )
    return job


def _run_job(job_id: int, session_factory, storage_service) -> None:
    settings = get_settings()
    service = ProcessingService(session_factory, storage_service=storage_service)
    try:
        stt_provider = get_configured_stt_provider(settings)
    except RuntimeError as exc:
        service.mark_failed(job_id, str(exc))
        return
    service.stt_provider = stt_provider
    service.run_transcription(job_id)


def _result_response(job: ProcessingJob) -> ProcessingResultResponse:
    transcript = job.audio_record.transcript
    summary = transcript.summary if transcript else None
    return ProcessingResultResponse(
        id=job.id,
        audio_record_id=job.audio_record_id,
        status=job.status,
        transcription_status=job.transcription_status,
        error_message=job.error_message,
        processing_stage=job.processing_stage,
        created_at=job.created_at,
        updated_at=job.updated_at,
        audio=audio_response(job.audio_record),
        event_title=job.audio_record.event.title,
        event_category=job.audio_record.event.category,
        transcript_text=(
            transcript.corrected_transcript or transcript.raw_transcript or transcript.text
            if transcript
            else None
        ),
        raw_transcript=(
            transcript.raw_transcript or transcript.text if transcript else None
        ),
        corrected_transcript=transcript.corrected_transcript if transcript else None,
        transcript_language=transcript.language if transcript else None,
        summary=summary.summary if summary else None,
        key_points=summary.key_points if summary else None,
        action_items=summary.action_items if summary else None,
        keywords=summary.keywords if summary else None,
        category=summary.category if summary else None,
        mood=summary.mood.value if summary and summary.mood else None,
        action_status=summary.action_status.value
        if summary and summary.action_status
        else None,
        message=job.error_message,
    )


@router.post(
    "/audio/{audio_record_id}",
    response_model=ProcessingJobResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def start_processing(
    audio_record_id: int,
    background_tasks: BackgroundTasks,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    audio = db.scalar(
        select(AudioRecord)
        .join(AudioRecord.event)
        .where(AudioRecord.id == audio_record_id, Event.user_id == current_user.id)
    )
    if audio is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Audio record not found")

    job = db.scalar(
        select(ProcessingJob).where(ProcessingJob.audio_record_id == audio_record_id)
    )
    if job is None:
        job = ProcessingJob(
            audio_record_id=audio_record_id,
            status=ProcessingStatus.PENDING,
        )
        db.add(job)
        try:
            db.commit()
            db.refresh(job)
        except IntegrityError:
            db.rollback()
            job = db.scalar(
                select(ProcessingJob).where(
                    ProcessingJob.audio_record_id == audio_record_id
                )
            )
            if job is None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Processing job could not be created",
                ) from None

    if job.status == ProcessingStatus.PROCESSING:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Audio is already being processed",
        )
    if job.status == ProcessingStatus.COMPLETED:
        return job

    job.status = ProcessingStatus.PENDING
    job.processing_stage = None
    job.error_message = None
    db.commit()
    session_factory = getattr(request.app.state, "testing_session", SessionLocal)
    background_tasks.add_task(_run_job, job.id, session_factory, storage)
    return job


@router.get("/{job_id}", response_model=ProcessingJobResponse)
def get_processing_status(
    job_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _owned_job(db, current_user, job_id)


@router.delete("/{job_id}", response_model=ProcessingJobResponse)
def cancel_processing(
    job_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = _owned_job(db, current_user, job_id)
    if job.status in (ProcessingStatus.COMPLETED, ProcessingStatus.FAILED):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Only active processing jobs can be cancelled",
        )
    if job.status == ProcessingStatus.PENDING and job.audio_record.file_path is not None:
        try:
            storage.delete(job.audio_record.file_path)
        except (AudioStorageError, OSError):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not remove temporary audio file",
            ) from None
        job.audio_record.file_path = None
    job.status = ProcessingStatus.CANCELLED
    job.error_message = "Processing cancelled by user"
    db.commit()
    db.refresh(job)
    return job


@router.get("/{job_id}/result", response_model=ProcessingResultResponse)
def get_processing_result(
    job_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = db.scalar(
        select(ProcessingJob)
        .options(
            joinedload(ProcessingJob.audio_record)
            .joinedload(AudioRecord.event),
            joinedload(ProcessingJob.audio_record)
            .joinedload(AudioRecord.transcript)
            .joinedload(Transcript.summary),
        )
        .join(ProcessingJob.audio_record)
        .join(AudioRecord.event)
        .where(ProcessingJob.id == job_id, Event.user_id == current_user.id)
    )
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Processing job not found")
    if job.status != ProcessingStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Processing has not completed",
        )

    return _result_response(job)


@router.post("/{job_id}/summary", response_model=ProcessingResultResponse)
def generate_summary(
    job_id: int,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = _owned_job(db, current_user, job_id)
    return _generate_summary_for_job(job, request, current_user, db)


@router.post(
    "/audio/{audio_record_id}/summary",
    response_model=ProcessingResultResponse,
)
def generate_audio_summary(
    audio_record_id: int,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = db.scalar(
        select(ProcessingJob)
        .join(ProcessingJob.audio_record)
        .join(AudioRecord.event)
        .where(
            AudioRecord.id == audio_record_id,
            Event.user_id == current_user.id,
        )
    )
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Processing job not found",
        )
    return _generate_summary_for_job(job, request, current_user, db)


def _generate_summary_for_job(
    job: ProcessingJob,
    request: Request,
    current_user: User,
    db: Session,
) -> ProcessingResultResponse:
    if job.status != ProcessingStatus.COMPLETED:
        raise HTTPException(status_code=409, detail="Transcription has not completed")
    session_factory = getattr(request.app.state, "testing_session", SessionLocal)
    service = ProcessingService(session_factory)
    try:
        _, llm_provider = get_configured_providers(get_settings())
        service.llm_provider = llm_provider
        service.generate_summary(job.id)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    db.expire_all()
    completed = _owned_job(db, current_user, job.id)
    completed = db.scalar(
        select(ProcessingJob)
        .options(
            joinedload(ProcessingJob.audio_record).joinedload(AudioRecord.event),
            joinedload(ProcessingJob.audio_record)
            .joinedload(AudioRecord.transcript)
            .joinedload(Transcript.summary),
        )
        .where(ProcessingJob.id == job.id)
    )
    return _result_response(completed)
