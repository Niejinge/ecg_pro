from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_db_session
from app.modules.cases.schemas import CaseListItem, CategoryItem
from app.modules.cases.service import list_public_cases, list_public_categories

router = APIRouter(tags=["cases"])


@router.get("/cases", response_model=list[CaseListItem])
def list_cases(db: Session = Depends(get_db_session)) -> list[CaseListItem]:
    return list_public_cases(db)


@router.get("/categories", response_model=list[CategoryItem])
def list_categories(db: Session = Depends(get_db_session)) -> list[CategoryItem]:
    return list_public_categories(db)
