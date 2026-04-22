from app.modules.cases.models import ECGCase, ECGCaseImage, ecg_case_tags
from app.modules.learning.models import Favorite, LearningProgress, WrongQuestion
from app.modules.quizzes.models import QuizAttempt, QuizAttemptItem, QuizQuestion, QuizQuestionOption
from app.modules.taxonomy.models import Category, Tag
from app.modules.users.models import Role, User, user_roles

# Import side effects are required so Alembic can discover all metadata.
import_models = (
    Role,
    User,
    user_roles,
    Category,
    Tag,
    ECGCase,
    ECGCaseImage,
    ecg_case_tags,
    QuizQuestion,
    QuizQuestionOption,
    QuizAttempt,
    QuizAttemptItem,
    LearningProgress,
    Favorite,
    WrongQuestion,
)

