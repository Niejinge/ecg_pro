from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import create_access_token, verify_password
from app.modules.auth import repository
from app.modules.auth.schemas import AuthUser, LoginResponse
from app.modules.users.models import User


def serialize_user(user: User) -> AuthUser:
    return AuthUser(
        id=user.id,
        username=user.username,
        display_name=user.display_name,
        is_active=user.is_active,
        is_superuser=user.is_superuser,
        role_codes=[role.code for role in user.roles],
    )


def authenticate_user(session: Session, username: str, password: str) -> User:
    user = repository.get_user_by_username(session, username)
    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is inactive.",
        )

    user.last_login_at = datetime.now(timezone.utc)
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def issue_login_response(user: User) -> LoginResponse:
    settings = get_settings()
    role_codes = [role.code for role in user.roles]
    access_token = create_access_token(
        subject=user.id,
        expires_minutes=settings.access_token_expire_minutes,
        extra_claims={"roles": role_codes, "username": user.username},
    )
    return LoginResponse(
        access_token=access_token,
        expires_in=settings.access_token_expire_minutes * 60,
        user=serialize_user(user),
    )

