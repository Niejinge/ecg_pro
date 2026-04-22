from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.core.deps import get_db_session, require_admin
from app.domain.enums import CaseStatus, DifficultyLevel, RiskLevel
from app.modules.cases.schemas import (
    AdminCaseListResponse,
    AdminCaseUpsertRequest,
    CaseListResponse,
    CaseDetailItem,
)
from app.modules.cases.service import (
    create_case,
    delete_case,
    get_admin_case_detail,
    get_public_case_detail,
    list_admin_cases,
    list_public_cases,
    offline_case,
    publish_case,
    update_case,
)
from app.modules.users.models import User

public_router = APIRouter(tags=["cases"])
admin_router = APIRouter(tags=["admin-cases"])


@public_router.get("/cases", response_model=CaseListResponse)
def list_cases(
    keyword: str | None = Query(default=None),
    category_id: str | None = Query(default=None),
    tag_id: str | None = Query(default=None),
    difficulty: DifficultyLevel | None = Query(default=None),
    risk_level: RiskLevel | None = Query(default=None),
    is_featured: bool | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db_session),
) -> CaseListResponse:
    return list_public_cases(
        db,
        keyword=keyword,
        category_id=category_id,
        tag_id=tag_id,
        difficulty=difficulty,
        risk_level=risk_level,
        is_featured=is_featured,
        page=page,
        page_size=page_size,
    )


@public_router.get("/cases/{case_id}", response_model=CaseDetailItem)
def get_case_detail(
    case_id: str,
    db: Session = Depends(get_db_session),
) -> CaseDetailItem:
    return get_public_case_detail(db, case_id)


@admin_router.get(
    "/cases",
    response_model=AdminCaseListResponse,
    dependencies=[Depends(require_admin)],
)
def list_cases_admin(
    keyword: str | None = Query(default=None),
    category_id: str | None = Query(default=None),
    tag_id: str | None = Query(default=None),
    difficulty: DifficultyLevel | None = Query(default=None),
    risk_level: RiskLevel | None = Query(default=None),
    status_filter: CaseStatus | None = Query(default=None, alias="status"),
    is_featured: bool | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db_session),
) -> AdminCaseListResponse:
    return list_admin_cases(
        db,
        keyword=keyword,
        category_id=category_id,
        tag_id=tag_id,
        difficulty=difficulty,
        risk_level=risk_level,
        status=status_filter,
        is_featured=is_featured,
        page=page,
        page_size=page_size,
    )


@admin_router.post(
    "/cases",
    response_model=CaseDetailItem,
    status_code=status.HTTP_201_CREATED,
)
def post_case(
    payload: AdminCaseUpsertRequest,
    db: Session = Depends(get_db_session),
    current_user: User = Depends(require_admin),
) -> CaseDetailItem:
    return create_case(db, payload, current_user)


@admin_router.get(
    "/cases/{case_id}",
    response_model=CaseDetailItem,
    dependencies=[Depends(require_admin)],
)
def get_case_admin(
    case_id: str,
    db: Session = Depends(get_db_session),
) -> CaseDetailItem:
    return get_admin_case_detail(db, case_id)


@admin_router.put("/cases/{case_id}", response_model=CaseDetailItem)
def put_case(
    case_id: str,
    payload: AdminCaseUpsertRequest,
    db: Session = Depends(get_db_session),
    _: User = Depends(require_admin),
) -> CaseDetailItem:
    return update_case(db, case_id, payload)


@admin_router.delete("/cases/{case_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_case(
    case_id: str,
    db: Session = Depends(get_db_session),
    _: User = Depends(require_admin),
) -> Response:
    delete_case(db, case_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@admin_router.post("/cases/{case_id}/publish", response_model=CaseDetailItem)
def publish_case_endpoint(
    case_id: str,
    db: Session = Depends(get_db_session),
    _: User = Depends(require_admin),
) -> CaseDetailItem:
    return publish_case(db, case_id)


@admin_router.post("/cases/{case_id}/offline", response_model=CaseDetailItem)
def offline_case_endpoint(
    case_id: str,
    db: Session = Depends(get_db_session),
    _: User = Depends(require_admin),
) -> CaseDetailItem:
    return offline_case(db, case_id)
