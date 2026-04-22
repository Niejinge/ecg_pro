from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.modules.quizzes.models import QuizAttempt, QuizAttemptItem, QuizQuestion


def list_questions_by_case(session: Session, case_id: str) -> list[QuizQuestion]:
    statement = (
        select(QuizQuestion)
        .options(selectinload(QuizQuestion.options))
        .where(QuizQuestion.case_id == case_id)
        .order_by(QuizQuestion.sort_order.asc(), QuizQuestion.created_at.asc())
    )
    return list(session.scalars(statement).all())


def get_question(session: Session, question_id: str) -> QuizQuestion | None:
    statement = (
        select(QuizQuestion)
        .options(selectinload(QuizQuestion.options))
        .where(QuizQuestion.id == question_id)
    )
    return session.scalar(statement)


def list_attempts_by_user(
    session: Session,
    *,
    user_id: str,
    case_id: str | None,
    page: int,
    page_size: int,
) -> tuple[list[QuizAttempt], int]:
    base_statement = select(QuizAttempt).where(QuizAttempt.user_id == user_id)
    if case_id:
        base_statement = base_statement.where(QuizAttempt.case_id == case_id)

    total = (
        session.scalar(
            select(func.count()).select_from(base_statement.order_by(None).subquery())
        )
        or 0
    )
    statement = (
        base_statement.order_by(QuizAttempt.submitted_at.desc(), QuizAttempt.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(session.scalars(statement).all()), total


def get_attempt_by_id(
    session: Session,
    *,
    user_id: str,
    attempt_id: str,
) -> QuizAttempt | None:
    statement = (
        select(QuizAttempt)
        .options(
            selectinload(QuizAttempt.items)
            .selectinload(QuizAttemptItem.question)
            .selectinload(QuizQuestion.options)
        )
        .where(QuizAttempt.user_id == user_id, QuizAttempt.id == attempt_id)
    )
    return session.scalar(statement)
