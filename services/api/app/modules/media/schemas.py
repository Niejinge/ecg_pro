from pydantic import BaseModel, Field


class UploadedImageItem(BaseModel):
    id: str
    case_id: str
    file_name: str
    file_url: str
    content_type: str | None
    is_primary: bool
    sort_order: int


class UpdateCaseImageRequest(BaseModel):
    is_primary: bool | None = None
    sort_order: int | None = None


class ReorderCaseImageItem(BaseModel):
    image_id: str
    sort_order: int


class ReorderCaseImagesRequest(BaseModel):
    items: list[ReorderCaseImageItem] = Field(default_factory=list, min_length=1)
