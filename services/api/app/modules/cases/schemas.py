from datetime import datetime

from pydantic import BaseModel, Field

from app.domain.enums import CaseStatus, DifficultyLevel, RiskLevel


class CaseCategorySummary(BaseModel):
    id: str
    name: str
    slug: str


class CaseTagSummary(BaseModel):
    id: str
    name: str
    slug: str


class CaseImageItem(BaseModel):
    id: str
    file_name: str
    file_url: str
    content_type: str | None
    is_primary: bool
    sort_order: int


class CaseListItem(BaseModel):
    id: str
    case_code: str
    title: str
    diagnosis: str
    difficulty: DifficultyLevel
    risk_level: RiskLevel
    category_name: str | None


class AdminCaseListItem(CaseListItem):
    status: CaseStatus
    is_featured: bool
    updated_at: datetime


class CaseDetailItem(BaseModel):
    id: str
    case_code: str
    title: str
    summary: str | None
    diagnosis: str
    rhythm_type: str | None
    heart_rate: str | None
    axis_description: str | None
    pr_description: str | None
    qrs_description: str | None
    st_t_description: str | None
    qt_description: str | None
    key_leads: list[str]
    clinical_significance: str | None
    differential_diagnosis: str | None
    treatment_plan: str | None
    urgent_actions: str | None
    follow_up_recommendations: str | None
    detailed_description: str | None
    interpretation_steps: list[str]
    learning_points: list[str]
    common_mistakes: list[str]
    memory_tips: list[str]
    difficulty: DifficultyLevel
    risk_level: RiskLevel
    status: CaseStatus
    is_featured: bool
    published_at: datetime | None
    category: CaseCategorySummary | None
    tags: list[CaseTagSummary]
    images: list[CaseImageItem]
    created_by: str | None
    created_at: datetime
    updated_at: datetime


class AdminCaseUpsertRequest(BaseModel):
    case_code: str = Field(min_length=1, max_length=32)
    title: str = Field(min_length=1, max_length=255)
    summary: str | None = None
    diagnosis: str = Field(min_length=1, max_length=255)
    rhythm_type: str | None = None
    heart_rate: str | None = None
    axis_description: str | None = None
    pr_description: str | None = None
    qrs_description: str | None = None
    st_t_description: str | None = None
    qt_description: str | None = None
    key_leads: list[str] = Field(default_factory=list)
    clinical_significance: str | None = None
    differential_diagnosis: str | None = None
    treatment_plan: str | None = None
    urgent_actions: str | None = None
    follow_up_recommendations: str | None = None
    detailed_description: str | None = None
    interpretation_steps: list[str] = Field(default_factory=list)
    learning_points: list[str] = Field(default_factory=list)
    common_mistakes: list[str] = Field(default_factory=list)
    memory_tips: list[str] = Field(default_factory=list)
    difficulty: DifficultyLevel = DifficultyLevel.beginner
    risk_level: RiskLevel = RiskLevel.low
    category_id: str | None = None
    tag_ids: list[str] = Field(default_factory=list)
    is_featured: bool = False
