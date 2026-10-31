import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.models import ActionStatus, AudioRecord, Event, Mood, Summary, Transcript, User
from app.models.base import Base


@pytest.fixture
def db(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path / 'models.db'}")

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(dbapi_connection, connection_record):
        dbapi_connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    session = session_factory()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def create_user(db):
    user = User(
        email="model@example.com",
        password_hash="hash",
        display_name="Model User",
    )
    db.add(user)
    db.flush()
    return user


def test_core_models_persist_with_optional_processing_results(db):
    user = create_user(db)
    event = Event(user=user, title="Team meeting", category="work")
    audio = AudioRecord(
        event=event,
        filename="meeting.wav",
        file_path="uploads/meeting.wav",
        format="wav",
        size=1024,
        duration=12.5,
    )
    transcript = Transcript(audio_record=audio, text="Meeting notes", language="en")
    summary = Summary(
        transcript=transcript,
        summary="Discussed milestones.",
        key_points=["Milestones"],
        action_items=["Send notes"],
        keywords=["project"],
        category="work",
        mood=Mood.POSITIVE,
        action_status=ActionStatus.PENDING,
    )
    db.add(event)
    db.commit()
    db.expire_all()

    saved = db.query(User).one()
    assert saved.events[0].audio_records[0].transcript.summary.mood is Mood.POSITIVE
    assert saved.events[0].audio_records[0].transcript.summary.action_items == ["Send notes"]


def test_user_event_and_event_audio_relationships(db):
    user = create_user(db)
    event = Event(user=user, title="Interview")
    event.audio_records.append(
        AudioRecord(
            filename="interview.mp3",
            file_path="uploads/interview.mp3",
            format="mp3",
            size=2048,
        )
    )
    db.add(event)
    db.commit()

    assert event in user.events
    assert event.audio_records[0].event is event


def test_transcript_and_summary_are_optional_and_one_to_one(db):
    user = create_user(db)
    audio = AudioRecord(
        event=Event(user=user, title="Unprocessed"),
        filename="raw.m4a",
        file_path="uploads/raw.m4a",
        format="m4a",
        size=1,
    )
    db.add(audio)
    db.commit()
    assert audio.transcript is None

    audio.transcript = Transcript(text="Processed")
    db.commit()
    assert audio.transcript.summary is None


def test_foreign_keys_and_unique_processing_relationships_are_enforced(db):
    db.add(
        Event(user_id=999, title="Invalid"),
    )
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()

    user = create_user(db)
    audio = AudioRecord(
        event=Event(user=user, title="Recording"),
        filename="recording.wav",
        file_path="uploads/recording.wav",
        format="wav",
        size=1,
    )
    audio.transcript = Transcript(text="Text")
    db.add(audio)
    db.commit()
    audio.transcript = Transcript(text="Another transcript")
    with pytest.raises(IntegrityError):
        db.commit()


def test_deleting_user_cascades_all_owned_data(db):
    user = create_user(db)
    event = Event(user=user, title="Deletable")
    audio = AudioRecord(
        event=event,
        filename="delete.wav",
        file_path="uploads/delete.wav",
        format="wav",
        size=1,
    )
    audio.transcript = Transcript(text="Delete me")
    audio.transcript.summary = Summary(summary="Delete me too")
    db.add(event)
    db.commit()
    event_id = event.id

    db.delete(user)
    db.commit()

    assert db.query(Event).filter_by(id=event_id).count() == 0
    assert db.query(AudioRecord).count() == 0
    assert db.query(Transcript).count() == 0
    assert db.query(Summary).count() == 0
