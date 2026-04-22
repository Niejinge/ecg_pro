from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db_session
from app.modules.auth.schemas import AuthUser, LoginRequest, LoginResponse
from app.modules.auth.service import authenticate_user, issue_login_response, serialize_user
from app.modules.users.models import User

router = APIRouter(tags=["auth"])


@router.post("/login", response_model=LoginResponse)
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db_session),
) -> LoginResponse:
    user = authenticate_user(db, payload.username, payload.password)
    return issue_login_response(user)


@router.get("/me", response_model=AuthUser)
def me(current_user: User = Depends(get_current_user)) -> AuthUser:
    return serialize_user(current_user)
