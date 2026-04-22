from datetime import datetime

from pydantic import BaseModel, Field

from app.domain.enums import AttemptMode, DifficultyLevel, QuestionType


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


class QuizAnswerSubmission(BaseModel):
    question_id: str
    selected_option_ids: list[str] = Field(default_factory=list)


class QuizSubmissionRequest(BaseModel):
    case_id: str
    mode: AttemptMode = AttemptMode.case_quiz
    answers: list[QuizAnswerSubmission] = Field(default_factory=list)


class QuizSubmissionResultItem(BaseModel):
    question_id: str
    selected_option_ids: list[str]
    correct_option_ids: list[str]
    is_correct: bool
    explanation: str | None


class QuizSubmissionResponse(BaseModel):
    attempt_id: str
    case_id: str
    score: int
    total_questions: int
    correct_count: int
    items: list[QuizSubmissionResultItem]


class QuizAttemptListItem(BaseModel):
    attempt_id: str
    case_id: str | None
    case_code: str | None
    case_title: str | None
    score: int
    total_questions: int
    correct_count: int
    submitted_at: datetime | None


class QuizAttemptListResponse(BaseModel):
    items: list[QuizAttemptListItem]
    total: int
    page: int
    page_size: int
    has_next: bool


class QuizAttemptDetailItem(BaseModel):
    attempt_id: str
    case_id: str | None
    case_code: str | None
    case_title: str | None
    mode: AttemptMode
    score: int
    total_questions: int
    correct_count: int
    submitted_at: datetime | None
    items: list[QuizSubmissionResultItem]
