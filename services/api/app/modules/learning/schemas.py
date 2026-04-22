from datetime import datetime

from pydantic import BaseModel

from app.domain.enums import LearningStatus


class LearningProgressItem(BaseModel):
    case_id: str
    case_code: str
    title: str
    diagnosis: str
    status: LearningStatus
    completion_rate: int
    best_score: int
    last_viewed_at: datetime | None


class FavoriteItem(BaseModel):
    case_id: str
    case_code: str
    title: str
    diagnosis: str


class WrongQuestionItem(BaseModel):
    question_id: str
    case_id: str
    case_code: str
    case_title: str
    stem: str
    wrong_count: int
    last_wrong_at: datetime | None
