from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import String, cast, func, or_, select
from sqlalchemy.orm import Session

from app.api.v1.auth import get_current_user
from app.infrastructure.database import get_db
from app.models import AudioRecord, Event, Summary, Transcript, User
from app.schemas.summary import SummaryListResponse, SummaryResponse, SummaryUpdate

router = APIRouter(tags=["summaries"])


def _summary_query(user: User):
    return (
        select(Summary, Transcript, AudioRecord, Event)
        .join(Summary.transcript)
        .join(Transcript.audio_record)
        .join(AudioRecord.event)
        .where(Event.user_id == user.id)
    )


def _to_response(
    summary: Summary,
    transcript: Transcript,
    audio: AudioRecord,
    event: Event,
) -> SummaryResponse:
    return SummaryResponse(
        id=summary.id,
        transcript_id=summary.transcript_id,
        audio_record_id=audio.id,
        event_id=event.id,
        event_title=event.title,
        audio_filename=audio.filename,
        summary=summary.summary,
        key_points=summary.key_points,
        action_items=summary.action_items,
        keywords=summary.keywords,
        category=summary.category,
        mood=summary.mood,
        action_status=summary.action_status,
        created_at=summary.created_at,
        updated_at=summary.updated_at,
    )


def _owned_summary(
    db: Session,
    user: User,
    summary_id: int,
) -> tuple[Summary, Transcript, AudioRecord, Event]:
    result = db.execute(
        _summary_query(user).where(Summary.id == summary_id)
    ).one_or_none()
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Summary not found",
        )
    return result


@router.get("/summaries", response_model=SummaryListResponse)
def list_summaries(
    search: str | None = Query(default=None, min_length=1, max_length=200),
    category: str | None = Query(default=None, max_length=100),
    mood: str | None = Query(default=None),
    action_status: str | None = Query(default=None),
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if mood is not None:
        _parse_enum(mood, "mood", ("Positive", "Neutral", "Negative"))
    if action_status is not None:
        _parse_enum(action_status, "action_status", ("Pending", "Completed", "No Action"))
    if date_from and date_to and date_from > date_to:
        raise HTTPException(status_code=422, detail="date_from must not be after date_to")

    filters = []
    if search:
        term = f"%{search.strip().lower()}%"
        filters.append(
            or_(
                func.lower(Event.title).like(term),
                func.lower(Summary.summary).like(term),
                func.lower(cast(Summary.keywords, String)).like(term),
            )
        )
    if category:
        filters.append(func.lower(Summary.category) == category.strip().lower())
    if mood:
        filters.append(Summary.mood == mood)
    if action_status:
        filters.append(Summary.action_status == action_status)
    if date_from:
        filters.append(Summary.created_at >= date_from)
    if date_to:
        filters.append(Summary.created_at <= date_to)

    base = _summary_query(current_user).where(*filters)
    total = db.scalar(
        select(func.count()).select_from(base.subquery())
    ) or 0
    rows = db.execute(
        base.order_by(Summary.created_at.desc(), Summary.id.desc())
        .offset(offset)
        .limit(limit)
    ).all()
    return SummaryListResponse(
        items=[_to_response(*row) for row in rows],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/summaries/{summary_id}", response_model=SummaryResponse)
def get_summary(
    summary_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _to_response(*_owned_summary(db, current_user, summary_id))


@router.patch("/summaries/{summary_id}", response_model=SummaryResponse)
def update_summary(
    summary_id: int,
    payload: SummaryUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    summary, transcript, audio, event = _owned_summary(db, current_user, summary_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(summary, field, value)
    db.commit()
    db.refresh(summary)
    return _to_response(summary, transcript, audio, event)


@router.delete("/summaries/{summary_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_summary(
    summary_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    summary, _, _, _ = _owned_summary(db, current_user, summary_id)
    db.delete(summary)
    db.commit()


@router.get("/events/{event_id}/summaries", response_model=SummaryListResponse)
def list_event_summaries(
    event_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.scalar(select(Event).where(Event.id == event_id, Event.user_id == current_user.id))
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")
    base = _summary_query(current_user).where(Event.id == event_id)
    rows = db.execute(base.order_by(Summary.created_at.desc(), Summary.id.desc())).all()
    return SummaryListResponse(
        items=[_to_response(*row) for row in rows],
        total=len(rows),
        limit=len(rows) or 20,
        offset=0,
    )


@router.get("/audio/{audio_record_id}/summary", response_model=SummaryResponse)
def get_audio_summary(
    audio_record_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = db.execute(
        _summary_query(current_user).where(AudioRecord.id == audio_record_id)
    ).one_or_none()
    if result is None:
        raise HTTPException(status_code=404, detail="Summary not found")
    return _to_response(*result)


def _parse_enum(value: str, field: str, allowed: tuple[str, ...]) -> str:
    if value not in allowed:
        raise HTTPException(
            status_code=422,
            detail=f"{field} must be one of: {', '.join(allowed)}",
        )
    return value
