from pydantic import BaseModel, ConfigDict

from app.domain.enums import DifficultyLevel, RiskLevel


class CaseListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    case_code: str
    title: str
    diagnosis: str
    difficulty: DifficultyLevel
    risk_level: RiskLevel
    category_name: str | None


class CategoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    slug: str
