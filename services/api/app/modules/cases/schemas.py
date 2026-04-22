from pydantic import BaseModel


class CaseListItem(BaseModel):
    id: str
    title: str
    diagnosis: str
    difficulty: str
    risk_level: str
    category: str


class CategoryItem(BaseModel):
    id: str
    name: str

