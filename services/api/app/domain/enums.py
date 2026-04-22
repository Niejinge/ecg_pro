from enum import Enum


class CaseStatus(str, Enum):
    draft = "draft"
    published = "published"
    offline = "offline"


class DifficultyLevel(str, Enum):
    beginner = "beginner"
    intermediate = "intermediate"
    advanced = "advanced"


class RiskLevel(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class QuestionType(str, Enum):
    single_choice = "single_choice"
    multiple_choice = "multiple_choice"
    true_false = "true_false"
    image_recognition = "image_recognition"


class AttemptMode(str, Enum):
    case_quiz = "case_quiz"
    category_quiz = "category_quiz"
    random_practice = "random_practice"
    wrong_question_retry = "wrong_question_retry"


class LearningStatus(str, Enum):
    not_started = "not_started"
    in_progress = "in_progress"
    completed = "completed"

