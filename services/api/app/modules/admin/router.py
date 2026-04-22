from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_db_session, require_admin
from app.modules.admin.schemas import DashboardSummary
from app.modules.admin.service import get_dashboard_summary
from app.modules.users.models import User

router = APIRouter(tags=["admin"])


@router.get("/dashboard/summary", response_model=DashboardSummary)
def dashboard_summary(
    db: Session = Depends(get_db_session),
    _: User = Depends(require_admin),
) -> DashboardSummary:
    return get_dashboard_summary(db)
