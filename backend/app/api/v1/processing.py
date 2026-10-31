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
from app.services.processing_service import ProcessingService

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
    ProcessingService(session_factory, storage_service=storage_service).run(job_id)


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

    transcript = job.audio_record.transcript
    summary = transcript.summary if transcript else None
    return ProcessingResultResponse(
        id=job.id,
        audio_record_id=job.audio_record_id,
        status=job.status,
        error_message=job.error_message,
        created_at=job.created_at,
        updated_at=job.updated_at,
        audio=audio_response(job.audio_record),
        transcript_text=transcript.text if transcript else None,
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
    )
