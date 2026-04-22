from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.modules.cases.models import ECGCaseImage


def list_case_images(session: Session, case_id: str) -> list[ECGCaseImage]:
    statement = (
        select(ECGCaseImage)
        .where(ECGCaseImage.case_id == case_id)
        .order_by(ECGCaseImage.sort_order.asc(), ECGCaseImage.created_at.asc())
    )
    return list(session.scalars(statement).all())


def get_case_image(session: Session, image_id: str) -> ECGCaseImage | None:
    statement = (
        select(ECGCaseImage)
        .options(selectinload(ECGCaseImage.case))
        .where(ECGCaseImage.id == image_id)
    )
    return session.scalar(statement)
