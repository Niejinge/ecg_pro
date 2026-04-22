from pydantic import BaseModel, ConfigDict, Field


class CategoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    slug: str
    description: str | None = None
    sort_order: int
    is_visible: bool
    parent_id: str | None = None


class TagItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    slug: str
    description: str | None = None


class CategoryUpsertRequest(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    slug: str = Field(min_length=1, max_length=128)
    description: str | None = None
    sort_order: int = 0
    is_visible: bool = True
    parent_id: str | None = None


class TagUpsertRequest(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    slug: str = Field(min_length=1, max_length=64)
    description: str | None = None

