from pydantic import BaseModel


class DashboardSummary(BaseModel):
    total_cases: int
    published_cases: int
    total_questions: int
    total_users: int

