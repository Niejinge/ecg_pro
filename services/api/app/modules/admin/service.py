from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain.enums import CaseStatus
from app.modules.admin.schemas import DashboardSummary
from app.modules.cases.models import ECGCase
from app.modules.quizzes.models import QuizQuestion
from app.modules.users.models import User


def get_dashboard_summary(session: Session) -> DashboardSummary:
    total_cases = session.scalar(select(func.count()).select_from(ECGCase)) or 0
    published_cases = (
        session.scalar(
            select(func.count())
            .select_from(ECGCase)
            .where(ECGCase.status == CaseStatus.published)
        )
        or 0
    )
    total_questions = session.scalar(select(func.count()).select_from(QuizQuestion)) or 0
    total_users = session.scalar(select(func.count()).select_from(User)) or 0

    return DashboardSummary(
        total_cases=total_cases,
        published_cases=published_cases,
        total_questions=total_questions,
        total_users=total_users,
    )

