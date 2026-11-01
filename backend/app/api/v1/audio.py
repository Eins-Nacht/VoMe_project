from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.v1.auth import get_current_user
from app.core.config import get_settings
from app.infrastructure.database import get_db
from app.models import AudioRecord, Event, User
from app.schemas.audio import AudioRecordResponse
from app.services.audio_storage_service import (
    ALLOWED_EXTENSIONS,
    CONTENT_TYPES,
    RESPONSE_MEDIA_TYPES,
    AudioStorageError,
    AudioStorageService,
)

router = APIRouter(prefix="/audio", tags=["audio"])
storage = AudioStorageService()
CHUNK_SIZE = 1024 * 1024


def _response(record: AudioRecord) -> AudioRecordResponse:
    return AudioRecordResponse(
        id=record.id,
        event_id=record.event_id,
        filename=record.filename,
        format=record.format,
        size=record.size,
        duration=record.duration,
        audio_path=record.file_path,
        created_at=record.created_at,
        updated_at=record.updated_at,
        client_recording_id=record.client_recording_id,
    )


def _owned_record(db: Session, user: User, record_id: int) -> AudioRecord:
    record = db.scalar(
        select(AudioRecord)
        .join(AudioRecord.event)
        .where(AudioRecord.id == record_id, Event.user_id == user.id)
    )
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Audio record not found")
    return record


@router.post("", response_model=AudioRecordResponse, status_code=status.HTTP_201_CREATED)
async def upload_audio(
    event_id: int = Form(...),
    client_recording_id: str | None = Form(default=None),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.scalar(select(Event).where(Event.id == event_id, Event.user_id == current_user.id))
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    if client_recording_id:
        existing = db.scalar(
            select(AudioRecord)
            .join(AudioRecord.event)
            .where(
                AudioRecord.client_recording_id == client_recording_id,
                Event.user_id == current_user.id,
            )
        )
        if existing is not None:
            return _response(existing)

    filename = Path(file.filename or "").name
    extension = Path(filename).suffix.lower().lstrip(".")
    if not filename or extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="Only .mp3, .m4a, and .wav files are supported")
    if file.content_type and file.content_type not in CONTENT_TYPES[extension]:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="Audio content type does not match the file extension")

    destination, relative_path = storage.create_path(extension)
    size = 0
    try:
        with destination.open("wb") as output:
            while chunk := await file.read(CHUNK_SIZE):
                size += len(chunk)
                if size > get_settings().max_audio_size_bytes:
                    raise HTTPException(status_code=status.HTTP_413_CONTENT_TOO_LARGE, detail="Audio file exceeds the maximum size")
                output.write(chunk)
    except HTTPException:
        destination.unlink(missing_ok=True)
        raise
    except OSError as exc:
        destination.unlink(missing_ok=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not store audio file") from exc
    finally:
        await file.close()

    record = AudioRecord(
        event=event,
        filename=filename,
        format=extension,
        size=size,
        file_path=relative_path,
        client_recording_id=client_recording_id,
    )
    try:
        db.add(record)
        db.commit()
        db.refresh(record)
    except SQLAlchemyError:
        db.rollback()
        destination.unlink(missing_ok=True)
        raise
    return _response(record)


@router.get("", response_model=list[AudioRecordResponse])
def list_audio(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    records = db.scalars(
        select(AudioRecord)
        .join(AudioRecord.event)
        .where(Event.user_id == current_user.id)
        .order_by(AudioRecord.created_at.desc())
    ).all()
    return [_response(record) for record in records]


@router.get("/{record_id}", response_model=AudioRecordResponse)
def get_audio(
    record_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _response(_owned_record(db, current_user, record_id))


@router.get("/{record_id}/file")
def download_audio(
    record_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = _owned_record(db, current_user, record_id)
    try:
        path = storage.resolve(record.file_path)
    except AudioStorageError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Audio file not found") from None
    if not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Audio file not found")
    return FileResponse(
        path,
        media_type=RESPONSE_MEDIA_TYPES[record.format],
        filename=record.filename,
    )


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_audio(
    record_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = _owned_record(db, current_user, record_id)
    try:
        storage.delete(record.file_path)
    except (AudioStorageError, OSError) as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not remove audio file") from exc
    db.delete(record)
    db.commit()
