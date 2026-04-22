from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.domain.enums import CaseStatus
from app.modules.cases.models import ECGCase
from app.modules.taxonomy.models import Category


def list_published_cases(session: Session) -> list[ECGCase]:
    statement = (
        select(ECGCase)
        .options(selectinload(ECGCase.category))
        .where(ECGCase.status == CaseStatus.published)
        .order_by(ECGCase.is_featured.desc(), ECGCase.created_at.desc())
    )
    return list(session.scalars(statement).all())


def list_visible_categories(session: Session) -> list[Category]:
    statement = (
        select(Category)
        .where(Category.is_visible.is_(True))
        .order_by(Category.sort_order.asc(), Category.name.asc())
    )
    return list(session.scalars(statement).all())

