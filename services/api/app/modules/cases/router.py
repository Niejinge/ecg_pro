from fastapi import APIRouter

from app.modules.cases.schemas import CaseListItem, CategoryItem

router = APIRouter(tags=["cases"])

_demo_cases = [
    CaseListItem(
        id="case-001",
        title="窦性心律基础判读",
        diagnosis="窦性心律",
        difficulty="beginner",
        risk_level="low",
        category="基础节律",
    ),
    CaseListItem(
        id="case-002",
        title="室上性心动过速识别",
        diagnosis="室上性心动过速",
        difficulty="intermediate",
        risk_level="high",
        category="快速性心律失常",
    ),
]

_demo_categories = [
    CategoryItem(id="cat-001", name="基础节律"),
    CategoryItem(id="cat-002", name="传导阻滞"),
    CategoryItem(id="cat-003", name="心肌缺血与梗死"),
]


@router.get("/cases", response_model=list[CaseListItem])
def list_cases() -> list[CaseListItem]:
    return _demo_cases


@router.get("/categories", response_model=list[CategoryItem])
def list_categories() -> list[CategoryItem]:
    return _demo_categories

