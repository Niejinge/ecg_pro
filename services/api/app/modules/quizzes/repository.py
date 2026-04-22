from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.modules.quizzes.models import QuizQuestion


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
