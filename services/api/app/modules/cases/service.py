from sqlalchemy.orm import Session

from app.modules.cases import repository
from app.modules.cases.schemas import CaseListItem, CategoryItem


def list_public_cases(session: Session) -> list[CaseListItem]:
    cases = repository.list_published_cases(session)
    return [
        CaseListItem(
            id=item.id,
            case_code=item.case_code,
            title=item.title,
            diagnosis=item.diagnosis,
            difficulty=item.difficulty,
            risk_level=item.risk_level,
            category_name=item.category.name if item.category else None,
        )
        for item in cases
    ]


def list_public_categories(session: Session) -> list[CategoryItem]:
    categories = repository.list_visible_categories(session)
    return [
        CategoryItem(
            id=item.id,
            name=item.name,
            slug=item.slug,
        )
        for item in categories
    ]

