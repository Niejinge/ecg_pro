from pathlib import Path
from shutil import copyfileobj

from fastapi import HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.modules.cases.models import ECGCaseImage
from app.modules.cases.repository import get_case
from app.modules.media import repository
from app.modules.media.schemas import UploadedImageItem

ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
}


def _build_storage_dir(case_id: str) -> Path:
    settings = get_settings()
    if settings.storage_backend != "local":
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Only local storage is implemented in the current stage.",
        )

    storage_dir = Path(settings.local_storage_path) / "case-images" / case_id
    storage_dir.mkdir(parents=True, exist_ok=True)
    return storage_dir


def _serialize(item: ECGCaseImage) -> UploadedImageItem:
    return UploadedImageItem(
        id=item.id,
        case_id=item.case_id,
        file_name=item.file_name,
        file_url=item.file_url,
        content_type=item.content_type,
        is_primary=item.is_primary,
        sort_order=item.sort_order,
    )


def upload_case_image(
    session: Session,
    case_id: str,
    file: UploadFile,
    *,
    is_primary: bool,
    sort_order: int,
) -> UploadedImageItem:
    ecg_case = get_case(session, case_id)
    if ecg_case is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )

    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported image type.",
        )

    safe_name = Path(file.filename or "image").name
    image = ECGCaseImage(
        case_id=case_id,
        file_name=safe_name,
        file_url="",
        content_type=file.content_type,
        is_primary=is_primary or not ecg_case.images,
        sort_order=sort_order,
    )
    session.add(image)
    session.flush()

    if image.is_primary:
        for existing_image in ecg_case.images:
            if existing_image.id != image.id:
                existing_image.is_primary = False

    storage_dir = _build_storage_dir(case_id)
    storage_name = f"{image.id}_{safe_name}"
    file_path = storage_dir / storage_name
    try:
        with file_path.open("wb") as output_stream:
            copyfileobj(file.file, output_stream)
    finally:
        file.file.close()

    settings = get_settings()
    image.file_url = (
        f"{settings.public_base_url}{settings.api_v1_prefix}/public/images/{image.id}/file"
    )
    session.add(image)
    session.commit()
    session.refresh(image)
    return _serialize(image)


def delete_case_image(session: Session, image_id: str) -> None:
    image = repository.get_case_image(session, image_id)
    if image is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case image not found.",
        )

    storage_dir = _build_storage_dir(image.case_id)
    for file_path in storage_dir.glob(f"{image.id}_*"):
        if file_path.is_file():
            file_path.unlink(missing_ok=True)

    session.delete(image)
    session.commit()


def get_case_image_file(session: Session, image_id: str) -> FileResponse:
    image = repository.get_case_image(session, image_id)
    if image is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case image not found.",
        )

    storage_dir = _build_storage_dir(image.case_id)
    for file_path in storage_dir.glob(f"{image.id}_*"):
        if file_path.is_file():
            return FileResponse(file_path, media_type=image.content_type)

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Image file not found.",
    )
