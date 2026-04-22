from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.modules.users.models import User


def get_user_by_username(session: Session, username: str) -> User | None:
    statement = (
        select(User)
        .options(selectinload(User.roles))
        .where(User.username == username)
    )
    return session.scalar(statement)


def get_user_by_id(session: Session, user_id: str) -> User | None:
    statement = select(User).options(selectinload(User.roles)).where(User.id == user_id)
    return session.scalar(statement)

