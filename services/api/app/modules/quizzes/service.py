from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.domain.enums import CaseStatus, LearningStatus, QuestionType
from app.modules.cases.repository import get_case
from app.modules.learning import repository as learning_repository
from app.modules.learning.models import LearningProgress, WrongQuestion
from app.modules.quizzes import repository
from app.modules.quizzes.models import QuizAttempt, QuizAttemptItem, QuizQuestion, QuizQuestionOption
from app.modules.quizzes.schemas import (
    AdminQuizOptionItem,
    AdminQuizQuestionItem,
    AdminQuizQuestionUpsertRequest,
    PublicQuizOptionItem,
    PublicQuizQuestionItem,
    QuizSubmissionRequest,
    QuizSubmissionResponse,
    QuizSubmissionResultItem,
)
from app.modules.users.models import User


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


def submit_quiz(
    session: Session,
    current_user: User,
    payload: QuizSubmissionRequest,
) -> QuizSubmissionResponse:
    ecg_case = get_case(session, payload.case_id)
    if ecg_case is None or ecg_case.status != CaseStatus.published:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Published case not found.",
        )

    questions = [
        item
        for item in repository.list_questions_by_case(session, payload.case_id)
        if item.is_active
    ]
    if not questions:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="No active quiz questions are available for this case.",
        )

    answers_map = {item.question_id: item for item in payload.answers}
    submitted_at = datetime.now(timezone.utc)
    attempt = QuizAttempt(
        user_id=current_user.id,
        case_id=payload.case_id,
        mode=payload.mode,
        total_questions=len(questions),
        correct_count=0,
        score=0,
        started_at=submitted_at,
        submitted_at=submitted_at,
    )
    session.add(attempt)
    session.flush()

    results: list[QuizSubmissionResultItem] = []
    correct_count = 0
    for question in questions:
        answer = answers_map.get(question.id)
        selected_option_ids = answer.selected_option_ids if answer else []
        valid_option_ids = {option.id for option in question.options}
        filtered_option_ids = [
            option_id for option_id in selected_option_ids if option_id in valid_option_ids
        ]
        correct_option_ids = sorted(
            [option.id for option in question.options if option.is_correct]
        )
        is_correct = set(filtered_option_ids) == set(correct_option_ids)
        if is_correct:
            correct_count += 1

        session.add(
            QuizAttemptItem(
                attempt_id=attempt.id,
                question_id=question.id,
                selected_option_ids=filtered_option_ids,
                is_correct=is_correct,
            )
        )

        if not is_correct:
            wrong_item = learning_repository.get_wrong_question(
                session,
                user_id=current_user.id,
                question_id=question.id,
            )
            if wrong_item is None:
                wrong_item = WrongQuestion(
                    user_id=current_user.id,
                    question_id=question.id,
                    wrong_count=1,
                    last_wrong_at=submitted_at,
                )
            else:
                wrong_item.wrong_count += 1
                wrong_item.last_wrong_at = submitted_at
            session.add(wrong_item)

        results.append(
            QuizSubmissionResultItem(
                question_id=question.id,
                selected_option_ids=filtered_option_ids,
                correct_option_ids=correct_option_ids,
                is_correct=is_correct,
                explanation=question.explanation,
            )
        )

    score = round(correct_count * 100 / len(questions))
    attempt.correct_count = correct_count
    attempt.score = score
    session.add(attempt)

    progress = learning_repository.get_learning_progress(
        session,
        user_id=current_user.id,
        case_id=payload.case_id,
    )
    if progress is None:
        progress = LearningProgress(
            user_id=current_user.id,
            case_id=payload.case_id,
            status=LearningStatus.completed,
            completion_rate=100,
            best_score=score,
            last_viewed_at=submitted_at,
        )
    else:
        progress.status = LearningStatus.completed
        progress.completion_rate = 100
        progress.best_score = max(progress.best_score, score)
        progress.last_viewed_at = submitted_at
    session.add(progress)

    session.commit()
    return QuizSubmissionResponse(
        attempt_id=attempt.id,
        case_id=payload.case_id,
        score=score,
        total_questions=len(questions),
        correct_count=correct_count,
        items=results,
    )
