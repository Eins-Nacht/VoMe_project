from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.v1.auth import get_current_user
from app.infrastructure.database import get_db
from app.models import Event, User
from app.schemas.event import EventCreate, EventResponse

router = APIRouter(prefix="/events", tags=["events"])


@router.post("", response_model=EventResponse, status_code=status.HTTP_201_CREATED)
def create_event(
    payload: EventCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = Event(
        user_id=current_user.id,
        title=payload.title.strip(),
        category=payload.category.strip() if payload.category else None,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


@router.get("", response_model=list[EventResponse])
def list_events(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.scalars(
        select(Event)
        .where(Event.user_id == current_user.id)
        .order_by(Event.created_at.desc(), Event.id.desc())
    ).all()


@router.get("/{event_id}", response_model=EventResponse)
def get_event(
    event_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.scalar(
        select(Event).where(Event.id == event_id, Event.user_id == current_user.id)
    )
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")
    return event
