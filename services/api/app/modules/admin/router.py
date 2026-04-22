from fastapi import APIRouter

from app.modules.admin.schemas import DashboardSummary

router = APIRouter(tags=["admin"])


@router.get("/dashboard/summary", response_model=DashboardSummary)
def get_dashboard_summary() -> DashboardSummary:
    return DashboardSummary(
        total_cases=2,
        published_cases=1,
        total_questions=12,
        total_users=0,
    )

