from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.domain.enums import CaseStatus, QuestionType
from app.modules.cases.repository import get_case
from app.modules.quizzes import repository
from app.modules.quizzes.models import QuizQuestion, QuizQuestionOption
from app.modules.quizzes.schemas import (
    AdminQuizOptionItem,
    AdminQuizQuestionItem,
    AdminQuizQuestionUpsertRequest,
    PublicQuizOptionItem,
    PublicQuizQuestionItem,
)


def _validate_options(payload: AdminQuizQuestionUpsertRequest) -> None:
    if not payload.options:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="At least one option is required.",
        )

    correct_count = sum(1 for option in payload.options if option.is_correct)
    if correct_count == 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="At least one correct option is required.",
        )

    if payload.question_type in {QuestionType.single_choice, QuestionType.true_false}:
        if correct_count != 1:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Single choice and true/false questions must have exactly one correct option.",
            )


def _serialize_admin_question(item: QuizQuestion) -> AdminQuizQuestionItem:
    return AdminQuizQuestionItem(
        id=item.id,
        case_id=item.case_id,
        stem=item.stem,
        explanation=item.explanation,
        question_type=item.question_type,
        difficulty=item.difficulty,
        sort_order=item.sort_order,
        is_active=item.is_active,
        options=[
            AdminQuizOptionItem(
                id=option.id,
                label=option.label,
                content=option.content,
                is_correct=option.is_correct,
                sort_order=option.sort_order,
            )
            for option in sorted(item.options, key=lambda option: (option.sort_order, option.label))
        ],
    )


def _serialize_public_question(item: QuizQuestion) -> PublicQuizQuestionItem:
    return PublicQuizQuestionItem(
        id=item.id,
        stem=item.stem,
        question_type=item.question_type,
        difficulty=item.difficulty,
        sort_order=item.sort_order,
        options=[
            PublicQuizOptionItem(
                id=option.id,
                label=option.label,
                content=option.content,
                sort_order=option.sort_order,
            )
            for option in sorted(item.options, key=lambda option: (option.sort_order, option.label))
        ],
    )


def list_public_case_questions(
    session: Session,
    case_id: str,
) -> list[PublicQuizQuestionItem]:
    case = get_case(session, case_id)
    if case is None or case.status != CaseStatus.published:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Published case not found.",
        )

    questions = [
        item for item in repository.list_questions_by_case(session, case_id) if item.is_active
    ]
    return [_serialize_public_question(item) for item in questions]


def list_admin_case_questions(
    session: Session,
    case_id: str,
) -> list[AdminQuizQuestionItem]:
    case = get_case(session, case_id)
    if case is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )

    return [
        _serialize_admin_question(item)
        for item in repository.list_questions_by_case(session, case_id)
    ]


def create_question(
    session: Session,
    case_id: str,
    payload: AdminQuizQuestionUpsertRequest,
) -> AdminQuizQuestionItem:
    if get_case(session, case_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )

    _validate_options(payload)
    question = QuizQuestion(
        case_id=case_id,
        stem=payload.stem,
        explanation=payload.explanation,
        question_type=payload.question_type,
        difficulty=payload.difficulty,
        sort_order=payload.sort_order,
        is_active=payload.is_active,
        options=[
            QuizQuestionOption(
                label=option.label,
                content=option.content,
                is_correct=option.is_correct,
                sort_order=option.sort_order,
            )
            for option in payload.options
        ],
    )
    session.add(question)
    session.commit()
    session.refresh(question)
    return _serialize_admin_question(repository.get_question(session, question.id) or question)


def update_question(
    session: Session,
    question_id: str,
    payload: AdminQuizQuestionUpsertRequest,
) -> AdminQuizQuestionItem:
    question = repository.get_question(session, question_id)
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    _validate_options(payload)
    question.stem = payload.stem
    question.explanation = payload.explanation
    question.question_type = payload.question_type
    question.difficulty = payload.difficulty
    question.sort_order = payload.sort_order
    question.is_active = payload.is_active
    question.options = [
        QuizQuestionOption(
            label=option.label,
            content=option.content,
            is_correct=option.is_correct,
            sort_order=option.sort_order,
        )
        for option in payload.options
    ]

    session.add(question)
    session.commit()
    session.refresh(question)
    return _serialize_admin_question(repository.get_question(session, question.id) or question)


def delete_question(session: Session, question_id: str) -> None:
    question = repository.get_question(session, question_id)
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    session.delete(question)
    session.commit()
