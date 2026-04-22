from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.modules.cases.models import ECGCaseImage


def get_case_image(session: Session, image_id: str) -> ECGCaseImage | None:
    statement = (
        select(ECGCaseImage)
        .options(selectinload(ECGCaseImage.case))
        .where(ECGCaseImage.id == image_id)
    )
    return session.scalar(statement)
