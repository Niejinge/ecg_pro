from fastapi import APIRouter, Depends, File, Form, Response, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.deps import get_db_session, require_admin
from app.modules.media.schemas import UploadedImageItem
from app.modules.media.service import (
    delete_case_image,
    get_case_image_file,
    upload_case_image,
)

public_router = APIRouter(tags=["media"])
admin_router = APIRouter(tags=["admin-media"], dependencies=[Depends(require_admin)])


@public_router.get("/images/{image_id}/file", response_class=FileResponse)
def get_image_file(
    image_id: str,
    db: Session = Depends(get_db_session),
) -> FileResponse:
    return get_case_image_file(db, image_id)


@admin_router.post(
    "/cases/{case_id}/images",
    response_model=UploadedImageItem,
    status_code=status.HTTP_201_CREATED,
)
def post_case_image(
    case_id: str,
    file: UploadFile = File(...),
    is_primary: bool = Form(False),
    sort_order: int = Form(0),
    db: Session = Depends(get_db_session),
) -> UploadedImageItem:
    return upload_case_image(
        db,
        case_id,
        file,
        is_primary=is_primary,
        sort_order=sort_order,
    )


@admin_router.delete("/case-images/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_case_image(
    image_id: str,
    db: Session = Depends(get_db_session),
) -> Response:
    delete_case_image(db, image_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
