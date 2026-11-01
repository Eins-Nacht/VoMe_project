from io import BytesIO

from app.api.v1.audio import storage
from app.models import Event, Summary, User


def register_and_login(client, email):
    client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct horse battery staple",
            "display_name": "Summary User",
        },
    )
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "correct horse battery staple"},
    )
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def create_event(client, email, title="Project planning"):
    db = client.app.state.testing_session()
    try:
        user = db.query(User).filter_by(email=email).one()
        event = Event(user=user, title=title)
        db.add(event)
        db.commit()
        return event.id
    finally:
        db.close()


def create_summary(client, headers, event_id, filename="meeting.mp3"):
    upload = client.post(
        "/api/v1/audio",
        headers=headers,
        data={"event_id": str(event_id)},
        files={"file": (filename, BytesIO(b"audio"), "audio/mpeg")},
    )
    audio_id = upload.json()["id"]
    job = client.post(f"/api/v1/processing/audio/{audio_id}", headers=headers)
    job_id = job.json()["id"]
    summary = client.post(
        f"/api/v1/processing/{job_id}/summary",
        headers=headers,
    )
    assert summary.status_code == 200
    return job_id, audio_id


def test_summary_crud_and_related_retrieval(client, tmp_path):
    storage.root = tmp_path / "audio"
    headers = register_and_login(client, "summary-crud@example.com")
    event_id = create_event(client, "summary-crud@example.com")
    job_id, audio_id = create_summary(client, headers, event_id)

    result = client.get(f"/api/v1/processing/{job_id}/result", headers=headers).json()
    db = client.app.state.testing_session()
    try:
        summary_id = db.query(Summary).one().id
    finally:
        db.close()

    detail = client.get(f"/api/v1/summaries/{summary_id}", headers=headers)
    by_audio = client.get(f"/api/v1/audio/{audio_id}/summary", headers=headers)
    by_event = client.get(f"/api/v1/events/{event_id}/summaries", headers=headers)
    assert detail.status_code == by_audio.status_code == by_event.status_code == 200
    assert detail.json()["event_id"] == event_id
    assert by_audio.json()["id"] == summary_id
    assert by_event.json()["items"][0]["id"] == summary_id

    updated = client.patch(
        f"/api/v1/summaries/{summary_id}",
        headers=headers,
        json={
            "summary": "Updated meeting summary",
            "key_points": ["Decision recorded"],
            "action_items": ["Send follow-up"],
            "keywords": ["planning", "follow-up"],
            "category": "Work",
            "mood": "Positive",
            "action_status": "Completed",
        },
    )
    assert updated.status_code == 200
    assert updated.json()["action_status"] == "Completed"
    assert updated.json()["keywords"] == ["planning", "follow-up"]

    deleted = client.delete(f"/api/v1/summaries/{summary_id}", headers=headers)
    assert deleted.status_code == 204
    assert client.get(f"/api/v1/summaries/{summary_id}", headers=headers).status_code == 404


def test_summary_search_filters_and_pagination(client, tmp_path):
    storage.root = tmp_path / "audio"
    headers = register_and_login(client, "summary-search@example.com")
    event_id = create_event(client, "summary-search@example.com", "Roadmap review")
    first_job, _ = create_summary(client, headers, event_id, "first.mp3")
    second_job, _ = create_summary(client, headers, event_id, "second.mp3")
    db = client.app.state.testing_session()
    try:
        summaries = db.query(Summary).order_by(Summary.id).all()
        first_id, second_id = summaries[0].id, summaries[1].id
    finally:
        db.close()

    client.patch(
        f"/api/v1/summaries/{first_id}",
        headers=headers,
        json={"category": "Personal", "mood": "Positive", "keywords": ["roadmap"]},
    )
    client.patch(
        f"/api/v1/summaries/{second_id}",
        headers=headers,
        json={"category": "Work", "mood": "Negative", "keywords": ["budget"]},
    )

    filtered = client.get(
        "/api/v1/summaries",
        headers=headers,
        params={"search": "budget", "category": "work", "mood": "Negative", "limit": 1},
    )
    assert filtered.status_code == 200
    assert filtered.json()["total"] == 1
    assert filtered.json()["items"][0]["id"] == second_id

    page = client.get(
        "/api/v1/summaries",
        headers=headers,
        params={"limit": 1, "offset": 1},
    )
    assert page.status_code == 200
    assert page.json()["total"] == 2
    assert len(page.json()["items"]) == 1


def test_summary_ownership_and_validation(client, tmp_path):
    storage.root = tmp_path / "audio"
    owner_headers = register_and_login(client, "summary-owner@example.com")
    other_headers = register_and_login(client, "summary-other@example.com")
    event_id = create_event(client, "summary-owner@example.com")
    job_id, _ = create_summary(client, owner_headers, event_id)
    db = client.app.state.testing_session()
    try:
        summary_id = db.query(Summary).one().id
    finally:
        db.close()

    assert client.get(f"/api/v1/summaries/{summary_id}", headers=other_headers).status_code == 404
    assert client.patch(
        f"/api/v1/summaries/{summary_id}",
        headers=owner_headers,
        json={"mood": "Unknown"},
    ).status_code == 422
    assert client.get(
        "/api/v1/summaries",
        headers=owner_headers,
        params={"action_status": "Invalid"},
    ).status_code == 422
    assert client.get(
        "/api/v1/summaries",
        headers=owner_headers,
        params={"date_from": "2026-11-01T00:00:00", "date_to": "2026-10-01T00:00:00"},
    ).status_code == 422
