from pydantic import BaseModel


class UploadedImageItem(BaseModel):
    id: str
    case_id: str
    file_name: str
    file_url: str
    content_type: str | None
    is_primary: bool
    sort_order: int
