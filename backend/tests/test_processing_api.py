from io import BytesIO
from pathlib import Path

from app.api.v1.audio import storage
from app.models import (
    AudioRecord,
    Event,
    ProcessingJob,
    ProcessingStatus,
    User,
)
from app.services.processing_service import ProcessingService


def register_and_login(client, email):
    client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct horse battery staple",
            "display_name": "Processing User",
        },
    )
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "correct horse battery staple"},
    )
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def create_event(client, email):
    db = client.app.state.testing_session()
    try:
        user = db.query(User).filter_by(email=email).one()
        event = Event(user=user, title="Processing event")
        db.add(event)
        db.commit()
        return event.id
    finally:
        db.close()


def upload(client, headers, event_id):
    return client.post(
        "/api/v1/audio",
        headers=headers,
        data={"event_id": str(event_id)},
        files={"file": ("sample.mp3", BytesIO(b"audio data"), "audio/mpeg")},
    )


def test_processing_creates_transcript_and_summary(client, tmp_path):
    storage.root = tmp_path / "audio"
    headers = register_and_login(client, "processing@example.com")
    event_id = create_event(client, "processing@example.com")
    audio = upload(client, headers, event_id).json()

    started = client.post(f"/api/v1/processing/audio/{audio['id']}", headers=headers)
    status_response = client.get(
        f"/api/v1/processing/{started.json()['id']}",
        headers=headers,
    )
    result = client.get(
        f"/api/v1/processing/{started.json()['id']}/result",
        headers=headers,
    )

    assert started.status_code == 202
    assert status_response.json()["status"] == "completed"
    assert result.status_code == 200
    assert result.json()["transcript_text"] == "Mock transcript for sample.mp3"
    assert result.json()["summary"] == "Mock summary: Mock transcript for sample.mp3"
    assert result.json()["mood"] == "Neutral"
    assert result.json()["action_status"] == "No Action"


def test_processing_prevents_duplicate_completed_job(client, tmp_path):
    storage.root = tmp_path / "audio"
    headers = register_and_login(client, "duplicate-processing@example.com")
    event_id = create_event(client, "duplicate-processing@example.com")
    audio = upload(client, headers, event_id).json()

    first = client.post(f"/api/v1/processing/audio/{audio['id']}", headers=headers)
    second = client.post(f"/api/v1/processing/audio/{audio['id']}", headers=headers)

    assert first.json()["id"] == second.json()["id"]
    db = client.app.state.testing_session()
    try:
        assert db.query(ProcessingJob).count() == 1
    finally:
        db.close()


def test_processing_requires_ownership_and_authentication(client, tmp_path):
    storage.root = tmp_path / "audio"
    owner_headers = register_and_login(client, "processing-owner@example.com")
    other_headers = register_and_login(client, "processing-other@example.com")
    event_id = create_event(client, "processing-owner@example.com")
    audio = upload(client, owner_headers, event_id).json()

    assert client.post(f"/api/v1/processing/audio/{audio['id']}").status_code == 401
    assert (
        client.post(
            f"/api/v1/processing/audio/{audio['id']}",
            headers=other_headers,
        ).status_code
        == 404
    )


def test_processing_failure_is_recorded_and_can_be_retried(client, tmp_path):
    storage.root = tmp_path / "audio"
    db = client.app.state.testing_session()
    try:
        user = User(
            email="failure@example.com",
            password_hash="hash",
            display_name="Failure User",
        )
        event = Event(user=user, title="Failure event")
        audio = AudioRecord(
            event=event,
            filename="failure.mp3",
            file_path="missing.mp3",
            format="mp3",
            size=1,
        )
        db.add(audio)
        db.commit()
        job = ProcessingJob(audio_record_id=audio.id)
        db.add(job)
        db.commit()
        job_id = job.id
        storage.root.mkdir(parents=True, exist_ok=True)
        (storage.root / "missing.mp3").write_bytes(b"audio")

        class FailingStt:
            def transcribe(self, audio_path: Path, filename: str):
                raise RuntimeError("mock STT failed")

        ProcessingService(
            client.app.state.testing_session,
            stt_provider=FailingStt(),
            storage_service=storage,
        ).run(job_id)
        db.expire_all()
        failed = db.get(ProcessingJob, job_id)
        assert failed.status is ProcessingStatus.FAILED
        assert failed.error_message == "mock STT failed"

        (storage.root / "missing.mp3").unlink()
        ProcessingService(
            client.app.state.testing_session,
            storage_service=storage,
        ).run(job_id)
        db.expire_all()
        retried = db.get(ProcessingJob, job_id)
        assert retried.status is ProcessingStatus.FAILED
    finally:
        db.close()
