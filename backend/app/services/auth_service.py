from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User
from app.repositories.user_repository import UserRepository


class DuplicateEmailError(Exception):
    pass


class InvalidCredentialsError(Exception):
    pass


class AuthService:
    def __init__(self, users: UserRepository | None = None) -> None:
        self.users = users or UserRepository()

    def register(
        self,
        db: Session,
        *,
        email: str,
        password: str,
        display_name: str,
    ) -> User:
        normalized_email = email.lower()
        if self.users.get_by_email(db, normalized_email) is not None:
            raise DuplicateEmailError

        try:
            return self.users.create(
                db,
                email=normalized_email,
                password_hash=hash_password(password),
                display_name=display_name.strip(),
            )
        except IntegrityError:
            db.rollback()
            raise DuplicateEmailError from None

    def authenticate(self, db: Session, *, email: str, password: str) -> User:
        user = self.users.get_by_email(db, email.lower())
        if user is None or not user.is_active or not verify_password(
            password, user.password_hash
        ):
            raise InvalidCredentialsError
        return user

    def issue_token(self, user: User) -> str:
        return create_access_token(str(user.id))

