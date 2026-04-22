from pydantic import BaseModel, Field

from app.domain.enums import DifficultyLevel, QuestionType


class QuizOptionUpsertRequest(BaseModel):
    label: str = Field(min_length=1, max_length=8)
    content: str = Field(min_length=1)
    is_correct: bool = False
    sort_order: int = 0


class AdminQuizQuestionUpsertRequest(BaseModel):
    stem: str = Field(min_length=1)
    explanation: str | None = None
    question_type: QuestionType = QuestionType.single_choice
    difficulty: DifficultyLevel = DifficultyLevel.beginner
    sort_order: int = 0
    is_active: bool = True
    options: list[QuizOptionUpsertRequest] = Field(default_factory=list)


class AdminQuizOptionItem(BaseModel):
    id: str
    label: str
    content: str
    is_correct: bool
    sort_order: int


class AdminQuizQuestionItem(BaseModel):
    id: str
    case_id: str
    stem: str
    explanation: str | None
    question_type: QuestionType
    difficulty: DifficultyLevel
    sort_order: int
    is_active: bool
    options: list[AdminQuizOptionItem]


class PublicQuizOptionItem(BaseModel):
    id: str
    label: str
    content: str
    sort_order: int


class PublicQuizQuestionItem(BaseModel):
    id: str
    stem: str
    question_type: QuestionType
    difficulty: DifficultyLevel
    sort_order: int
    options: list[PublicQuizOptionItem]
