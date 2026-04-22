from fastapi import APIRouter, Depends, File, Form, Response, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.deps import get_db_session, require_admin
from app.modules.media.schemas import (
    ReorderCaseImagesRequest,
    UpdateCaseImageRequest,
    UploadedImageItem,
)
from app.modules.media.service import (
    delete_case_image,
    get_case_image_file,
    reorder_case_images,
    update_case_image,
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


@admin_router.patch("/case-images/{image_id}", response_model=UploadedImageItem)
def patch_case_image(
    image_id: str,
    payload: UpdateCaseImageRequest,
    db: Session = Depends(get_db_session),
) -> UploadedImageItem:
    return update_case_image(db, image_id, payload)


@admin_router.put(
    "/cases/{case_id}/images/order",
    response_model=list[UploadedImageItem],
)
def put_case_image_order(
    case_id: str,
    payload: ReorderCaseImagesRequest,
    db: Session = Depends(get_db_session),
) -> list[UploadedImageItem]:
    return reorder_case_images(db, case_id, payload)


@admin_router.delete("/case-images/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_case_image(
    image_id: str,
    db: Session = Depends(get_db_session),
) -> Response:
    delete_case_image(db, image_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
