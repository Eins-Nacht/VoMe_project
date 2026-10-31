from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User


class UserRepository:
    def get_by_email(self, db: Session, email: str) -> User | None:
        return db.scalar(select(User).where(User.email == email))

    def get_by_id(self, db: Session, user_id: int) -> User | None:
        return db.get(User, user_id)

    def create(
        self,
        db: Session,
        *,
        email: str,
        password_hash: str,
        display_name: str,
    ) -> User:
        user = User(
            email=email,
            password_hash=password_hash,
            display_name=display_name,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

