from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db_session
from app.modules.learning.schemas import FavoriteItem, LearningProgressItem, WrongQuestionItem
from app.modules.learning.service import (
    add_favorite,
    list_progress,
    list_user_favorites,
    list_user_wrong_questions,
    mark_case_viewed,
    remove_favorite,
)
from app.modules.users.models import User

router = APIRouter(tags=["learning"])


@router.get("/learning/progress", response_model=list[LearningProgressItem])
def get_learning_progress(
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
) -> list[LearningProgressItem]:
    return list_progress(db, current_user)


@router.post("/learning/cases/{case_id}/view", response_model=LearningProgressItem)
def post_case_view(
    case_id: str,
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
) -> LearningProgressItem:
    return mark_case_viewed(db, current_user, case_id)


@router.get("/favorites", response_model=list[FavoriteItem])
def get_favorites(
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
) -> list[FavoriteItem]:
    return list_user_favorites(db, current_user)


@router.post("/favorites/{case_id}", response_model=FavoriteItem, status_code=status.HTTP_201_CREATED)
def post_favorite(
    case_id: str,
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
) -> FavoriteItem:
    return add_favorite(db, current_user, case_id)


@router.delete("/favorites/{case_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_favorite(
    case_id: str,
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
) -> Response:
    remove_favorite(db, current_user, case_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/wrong-questions", response_model=list[WrongQuestionItem])
def get_wrong_questions(
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
) -> list[WrongQuestionItem]:
    return list_user_wrong_questions(db, current_user)
