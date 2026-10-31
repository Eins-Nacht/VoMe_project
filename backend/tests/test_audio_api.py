from io import BytesIO

import pytest
from app.api.v1.audio import storage
from app.models import Event, User


def register_and_login(client, email):
    client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct horse battery staple",
            "display_name": "Audio User",
        },
    )
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "correct horse battery staple"},
    )
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def create_event(client, email, title="Recording"):
    db = client.app.state.testing_session()
    try:
        user = db.query(User).filter_by(email=email).one()
        event = Event(user=user, title=title)
        db.add(event)
        db.commit()
        return event.id
    finally:
        db.close()


@pytest.fixture
def audio_client(client, tmp_path):
    storage.root = tmp_path / "audio"
    yield client
    storage.root = tmp_path / "audio"


def upload(audio_client, headers, event_id, filename="sample.mp3", content=b"audio data"):
    return audio_client.post(
        "/api/v1/audio",
        headers=headers,
        data={"event_id": str(event_id)},
        files={"file": (filename, BytesIO(content), "audio/mpeg")},
    )


def test_upload_persists_metadata_and_file(audio_client):
    headers = register_and_login(audio_client, "owner@example.com")
    event_id = create_event(audio_client, "owner@example.com")

    response = upload(audio_client, headers, event_id)

    assert response.status_code == 201
    body = response.json()
    assert body["filename"] == "sample.mp3"
    assert body["format"] == "mp3"
    assert body["size"] == len(b"audio data")
    assert (storage.root / body["audio_path"]).read_bytes() == b"audio data"


def test_list_details_and_download_are_owned(audio_client):
    headers = register_and_login(audio_client, "list-owner@example.com")
    event_id = create_event(audio_client, "list-owner@example.com")
    created = upload(audio_client, headers, event_id)
    record_id = created.json()["id"]

    listed = audio_client.get("/api/v1/audio", headers=headers)
    detail = audio_client.get(f"/api/v1/audio/{record_id}", headers=headers)
    downloaded = audio_client.get(f"/api/v1/audio/{record_id}/file", headers=headers)

    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()] == [record_id]
    assert detail.json()["id"] == record_id
    assert downloaded.status_code == 200
    assert downloaded.content == b"audio data"
    assert downloaded.headers["content-type"] == "audio/mpeg"


def test_invalid_extension_and_oversized_file_are_rejected(audio_client, monkeypatch):
    headers = register_and_login(audio_client, "validation@example.com")
    event_id = create_event(audio_client, "validation@example.com")

    invalid = upload(audio_client, headers, event_id, "sample.txt")
    assert invalid.status_code == 415

    monkeypatch.setenv("MAX_AUDIO_SIZE_BYTES", "3")
    from app.core.config import get_settings

    get_settings.cache_clear()
    oversized = upload(audio_client, headers, event_id)
    assert oversized.status_code == 413
    assert not list(storage.root.glob("*"))
    get_settings.cache_clear()


def test_ownership_protects_records_and_deletion_removes_file(audio_client):
    owner_headers = register_and_login(audio_client, "first@example.com")
    event_id = create_event(audio_client, "first@example.com")
    created = upload(audio_client, owner_headers, event_id)
    record_id = created.json()["id"]
    path = storage.root / created.json()["audio_path"]

    other_headers = register_and_login(audio_client, "second@example.com")
    assert audio_client.get(f"/api/v1/audio/{record_id}", headers=other_headers).status_code == 404
    assert audio_client.get(f"/api/v1/audio/{record_id}/file", headers=other_headers).status_code == 404
    assert audio_client.delete(f"/api/v1/audio/{record_id}", headers=other_headers).status_code == 404
    assert path.exists()

    deleted = audio_client.delete(f"/api/v1/audio/{record_id}", headers=owner_headers)
    assert deleted.status_code == 204
    assert not path.exists()
    assert audio_client.get(f"/api/v1/audio/{record_id}", headers=owner_headers).status_code == 404


def test_deletion_succeeds_when_file_is_already_missing(audio_client):
    headers = register_and_login(audio_client, "missing-file@example.com")
    event_id = create_event(audio_client, "missing-file@example.com")
    created = upload(audio_client, headers, event_id)
    record_id = created.json()["id"]
    (storage.root / created.json()["audio_path"]).unlink()

    response = audio_client.delete(f"/api/v1/audio/{record_id}", headers=headers)

    assert response.status_code == 204


def test_upload_requires_owned_event(audio_client):
    headers = register_and_login(audio_client, "event-owner@example.com")
    other_headers = register_and_login(audio_client, "event-other@example.com")
    event_id = create_event(audio_client, "event-owner@example.com")

    response = upload(audio_client, other_headers, event_id)

    assert response.status_code == 404
