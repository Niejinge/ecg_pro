from dataclasses import dataclass

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.domain.enums import CaseStatus
from app.modules.cases.models import ECGCase


def _case_options():
    return (
        selectinload(ECGCase.category),
        selectinload(ECGCase.tags),
        selectinload(ECGCase.images),
    )


@dataclass
class CaseQueryFilters:
    keyword: str | None = None
    category_id: str | None = None
    tag_id: str | None = None
    difficulty: str | None = None
    risk_level: str | None = None
    status: str | None = None
    is_featured: bool | None = None
    page: int = 1
    page_size: int = 20


def _apply_filters(statement, filters: CaseQueryFilters, *, public_only: bool):
    if public_only:
        statement = statement.where(ECGCase.status == CaseStatus.published)
    elif filters.status:
        statement = statement.where(ECGCase.status == filters.status)

    if filters.keyword:
        keyword = f"%{filters.keyword.strip()}%"
        statement = statement.where(
            or_(
                ECGCase.case_code.ilike(keyword),
                ECGCase.title.ilike(keyword),
                ECGCase.diagnosis.ilike(keyword),
            )
        )

    if filters.category_id:
        statement = statement.where(ECGCase.category_id == filters.category_id)

    if filters.tag_id:
        statement = statement.where(ECGCase.tags.any(id=filters.tag_id))

    if filters.difficulty:
        statement = statement.where(ECGCase.difficulty == filters.difficulty)

    if filters.risk_level:
        statement = statement.where(ECGCase.risk_level == filters.risk_level)

    if filters.is_featured is not None:
        statement = statement.where(ECGCase.is_featured.is_(filters.is_featured))

    return statement


def list_cases(
    session: Session,
    filters: CaseQueryFilters,
    *,
    public_only: bool,
) -> tuple[list[ECGCase], int]:
    base_statement = select(ECGCase.id)
    base_statement = _apply_filters(base_statement, filters, public_only=public_only)

    total = session.scalar(select(func.count()).select_from(base_statement.subquery())) or 0
    offset = (filters.page - 1) * filters.page_size

    id_statement = base_statement.order_by(
        ECGCase.is_featured.desc(),
        ECGCase.updated_at.desc(),
        ECGCase.created_at.desc(),
    ).offset(offset).limit(filters.page_size)
    case_ids = list(session.scalars(id_statement).all())
    if not case_ids:
        return [], total

    statement = (
        select(ECGCase)
        .options(*_case_options())
        .where(ECGCase.id.in_(case_ids))
        .order_by(
            ECGCase.is_featured.desc(),
            ECGCase.updated_at.desc(),
            ECGCase.created_at.desc(),
        )
    )
    return list(session.scalars(statement).all()), total


def get_case(session: Session, case_id: str) -> ECGCase | None:
    statement = select(ECGCase).options(*_case_options()).where(ECGCase.id == case_id)
    return session.scalar(statement)


def get_case_by_code(session: Session, case_code: str) -> ECGCase | None:
    statement = select(ECGCase).where(ECGCase.case_code == case_code)
    return session.scalar(statement)
