from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db_session, require_admin
from app.modules.quizzes.schemas import (
    AdminQuizQuestionItem,
    AdminQuizQuestionUpsertRequest,
    PublicQuizQuestionItem,
    QuizSubmissionRequest,
    QuizSubmissionResponse,
)
from app.modules.quizzes.service import (
    create_question,
    delete_question,
    list_admin_case_questions,
    list_public_case_questions,
    submit_quiz,
    update_question,
)
from app.modules.users.models import User

public_router = APIRouter(tags=["quizzes"])
admin_router = APIRouter(tags=["admin-quizzes"], dependencies=[Depends(require_admin)])
user_router = APIRouter(tags=["user-quizzes"])


@public_router.get("/cases/{case_id}/quiz", response_model=list[PublicQuizQuestionItem])
def get_public_case_quiz(
    case_id: str,
    db: Session = Depends(get_db_session),
) -> list[PublicQuizQuestionItem]:
    return list_public_case_questions(db, case_id)


@admin_router.get("/cases/{case_id}/questions", response_model=list[AdminQuizQuestionItem])
def get_admin_case_questions(
    case_id: str,
    db: Session = Depends(get_db_session),
) -> list[AdminQuizQuestionItem]:
    return list_admin_case_questions(db, case_id)


@admin_router.post(
    "/cases/{case_id}/questions",
    response_model=AdminQuizQuestionItem,
    status_code=status.HTTP_201_CREATED,
)
def post_question(
    case_id: str,
    payload: AdminQuizQuestionUpsertRequest,
    db: Session = Depends(get_db_session),
) -> AdminQuizQuestionItem:
    return create_question(db, case_id, payload)


@admin_router.put("/questions/{question_id}", response_model=AdminQuizQuestionItem)
def put_question(
    question_id: str,
    payload: AdminQuizQuestionUpsertRequest,
    db: Session = Depends(get_db_session),
) -> AdminQuizQuestionItem:
    return update_question(db, question_id, payload)


@admin_router.delete("/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_question(
    question_id: str,
    db: Session = Depends(get_db_session),
) -> Response:
    delete_question(db, question_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@user_router.post("/quiz/submit", response_model=QuizSubmissionResponse)
def submit_quiz_endpoint(
    payload: QuizSubmissionRequest,
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
) -> QuizSubmissionResponse:
    return submit_quiz(db, current_user, payload)
