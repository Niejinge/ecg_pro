from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.learning.models import Favorite, LearningProgress, WrongQuestion


def get_learning_progress(
    session: Session,
    *,
    user_id: str,
    case_id: str,
) -> LearningProgress | None:
    statement = select(LearningProgress).where(
        LearningProgress.user_id == user_id,
        LearningProgress.case_id == case_id,
    )
    return session.scalar(statement)


def list_learning_progress(session: Session, *, user_id: str) -> list[LearningProgress]:
    statement = (
        select(LearningProgress)
        .where(LearningProgress.user_id == user_id)
        .order_by(LearningProgress.last_viewed_at.desc().nullslast())
    )
    return list(session.scalars(statement).all())


def get_favorite(session: Session, *, user_id: str, case_id: str) -> Favorite | None:
    statement = select(Favorite).where(
        Favorite.user_id == user_id,
        Favorite.case_id == case_id,
    )
    return session.scalar(statement)


def list_favorites(session: Session, *, user_id: str) -> list[Favorite]:
    statement = select(Favorite).where(Favorite.user_id == user_id)
    return list(session.scalars(statement).all())


def get_wrong_question(
    session: Session,
    *,
    user_id: str,
    question_id: str,
) -> WrongQuestion | None:
    statement = select(WrongQuestion).where(
        WrongQuestion.user_id == user_id,
        WrongQuestion.question_id == question_id,
    )
    return session.scalar(statement)


def list_wrong_questions(session: Session, *, user_id: str) -> list[WrongQuestion]:
    statement = (
        select(WrongQuestion)
        .where(WrongQuestion.user_id == user_id)
        .order_by(WrongQuestion.last_wrong_at.desc().nullslast())
    )
    return list(session.scalars(statement).all())
