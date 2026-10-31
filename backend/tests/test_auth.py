from argon2 import PasswordHasher
from app.models.user import User


def registration_payload(email="user@example.com"):
    return {
        "email": email,
        "password": "correct horse battery staple",
        "display_name": "Test User",
    }


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_successful_registration(client):
    response = client.post("/api/v1/auth/register", json=registration_payload())
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "user@example.com"
    assert body["display_name"] == "Test User"
    assert "password_hash" not in body


def test_duplicate_email_rejected(client):
    payload = registration_payload()
    assert client.post("/api/v1/auth/register", json=payload).status_code == 201
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 409


def test_password_is_argon2_hash(client):
    client.post("/api/v1/auth/register", json=registration_payload())

    db = client.app.state.testing_session()
    try:
        user = db.query(User).filter_by(email="user@example.com").one()
        assert user.password_hash.startswith("$argon2")
        assert PasswordHasher().verify(
            user.password_hash, "correct horse battery staple"
        )
    finally:
        db.close()


def test_successful_login_and_authenticated_me(client):
    client.post("/api/v1/auth/register", json=registration_payload())
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct horse battery staple"},
    )
    assert login.status_code == 200
    token = login.json()["access_token"]
    assert login.json()["token_type"] == "bearer"

    me = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me.status_code == 200
    assert me.json()["email"] == "user@example.com"


def test_incorrect_password_rejected(client):
    client.post("/api/v1/auth/register", json=registration_payload())
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "wrong password"},
    )
    assert response.status_code == 401


def test_invalid_or_missing_jwt_rejected(client):
    assert client.get("/api/v1/auth/me").status_code == 401
    assert client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer not-a-real-token"},
    ).status_code == 401
