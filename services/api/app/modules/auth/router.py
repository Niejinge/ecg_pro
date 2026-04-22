from fastapi import APIRouter

from app.modules.auth.schemas import LoginRequest, LoginResponse

router = APIRouter(tags=["auth"])


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest) -> LoginResponse:
    return LoginResponse(
        access_token=f"bootstrap-token-for-{payload.username}",
        user_role="admin" if payload.username.startswith("admin") else "user",
    )

