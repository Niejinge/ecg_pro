from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.domain.enums import CaseStatus
from app.modules.cases.models import ECGCase


def _case_options():
    return (
        selectinload(ECGCase.category),
        selectinload(ECGCase.tags),
        selectinload(ECGCase.images),
    )


def list_published_cases(session: Session) -> list[ECGCase]:
    statement = (
        select(ECGCase)
        .options(*_case_options())
        .where(ECGCase.status == CaseStatus.published)
        .order_by(ECGCase.is_featured.desc(), ECGCase.created_at.desc())
    )
    return list(session.scalars(statement).all())


def list_all_cases(session: Session) -> list[ECGCase]:
    statement = (
        select(ECGCase)
        .options(*_case_options())
        .order_by(ECGCase.updated_at.desc(), ECGCase.created_at.desc())
    )
    return list(session.scalars(statement).all())


def get_case(session: Session, case_id: str) -> ECGCase | None:
    statement = select(ECGCase).options(*_case_options()).where(ECGCase.id == case_id)
    return session.scalar(statement)


def get_case_by_code(session: Session, case_code: str) -> ECGCase | None:
    statement = select(ECGCase).where(ECGCase.case_code == case_code)
    return session.scalar(statement)
