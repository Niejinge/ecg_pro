from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.domain.enums import CaseStatus
from app.domain.enums import LearningStatus
from app.modules.cases.repository import get_case
from app.modules.learning import repository
from app.modules.learning.models import Favorite, LearningProgress
from app.modules.learning.schemas import FavoriteItem, LearningProgressItem, WrongQuestionItem
from app.modules.quizzes.models import QuizQuestion
from app.modules.users.models import User


def _serialize_progress(session: Session, item: LearningProgress) -> LearningProgressItem:
    ecg_case = get_case(session, item.case_id)
    if ecg_case is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Learning progress case not found.",
        )

    return LearningProgressItem(
        case_id=ecg_case.id,
        case_code=ecg_case.case_code,
        title=ecg_case.title,
        diagnosis=ecg_case.diagnosis,
        status=item.status,
        completion_rate=item.completion_rate,
        best_score=item.best_score,
        last_viewed_at=item.last_viewed_at,
        )


def _get_published_case(session: Session, case_id: str):
    ecg_case = get_case(session, case_id)
    if ecg_case is None or ecg_case.status != CaseStatus.published:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Published case not found.",
        )
    return ecg_case


def list_progress(session: Session, current_user: User) -> list[LearningProgressItem]:
    return [
        _serialize_progress(session, item)
        for item in repository.list_learning_progress(session, user_id=current_user.id)
    ]


def mark_case_viewed(
    session: Session,
    current_user: User,
    case_id: str,
) -> LearningProgressItem:
    ecg_case = _get_published_case(session, case_id)

    item = repository.get_learning_progress(
        session,
        user_id=current_user.id,
        case_id=case_id,
    )
    if item is None:
        item = LearningProgress(
            user_id=current_user.id,
            case_id=case_id,
            status=LearningStatus.in_progress,
            completion_rate=10,
            best_score=0,
            last_viewed_at=datetime.now(timezone.utc),
        )
    else:
        item.last_viewed_at = datetime.now(timezone.utc)
        if item.status == LearningStatus.not_started:
            item.status = LearningStatus.in_progress
        item.completion_rate = max(item.completion_rate, 10)

    session.add(item)
    session.commit()
    session.refresh(item)
    return _serialize_progress(session, item)


def add_favorite(
    session: Session,
    current_user: User,
    case_id: str,
) -> FavoriteItem:
    ecg_case = _get_published_case(session, case_id)

    favorite = repository.get_favorite(session, user_id=current_user.id, case_id=case_id)
    if favorite is None:
        favorite = Favorite(user_id=current_user.id, case_id=case_id)
        session.add(favorite)
        session.commit()

    return FavoriteItem(
        case_id=ecg_case.id,
        case_code=ecg_case.case_code,
        title=ecg_case.title,
        diagnosis=ecg_case.diagnosis,
    )


def remove_favorite(session: Session, current_user: User, case_id: str) -> None:
    favorite = repository.get_favorite(session, user_id=current_user.id, case_id=case_id)
    if favorite is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Favorite not found.",
        )

    session.delete(favorite)
    session.commit()


def list_user_favorites(session: Session, current_user: User) -> list[FavoriteItem]:
    items = []
    for favorite in repository.list_favorites(session, user_id=current_user.id):
        ecg_case = get_case(session, favorite.case_id)
        if ecg_case is None:
            continue
        items.append(
            FavoriteItem(
                case_id=ecg_case.id,
                case_code=ecg_case.case_code,
                title=ecg_case.title,
                diagnosis=ecg_case.diagnosis,
            )
        )
    return items


def list_user_wrong_questions(
    session: Session,
    current_user: User,
) -> list[WrongQuestionItem]:
    items: list[WrongQuestionItem] = []
    for wrong_item in repository.list_wrong_questions(session, user_id=current_user.id):
        question = session.get(QuizQuestion, wrong_item.question_id)
        if question is None:
            continue
        ecg_case = get_case(session, question.case_id)
        if ecg_case is None:
            continue
        items.append(
            WrongQuestionItem(
                question_id=question.id,
                case_id=ecg_case.id,
                case_code=ecg_case.case_code,
                case_title=ecg_case.title,
                stem=question.stem,
                wrong_count=wrong_item.wrong_count,
                last_wrong_at=wrong_item.last_wrong_at,
            )
        )
    return items
