from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.core.deps import get_db_session, require_admin
from app.modules.taxonomy.schemas import (
    CategoryItem,
    CategoryUpsertRequest,
    TagItem,
    TagUpsertRequest,
)
from app.modules.taxonomy.service import (
    create_category,
    create_tag,
    delete_category,
    delete_tag,
    list_admin_categories,
    list_admin_tags,
    list_public_categories,
    list_public_tags,
    update_category,
    update_tag,
)

public_router = APIRouter(tags=["taxonomy"])
admin_router = APIRouter(tags=["admin-taxonomy"], dependencies=[Depends(require_admin)])


@public_router.get("/categories", response_model=list[CategoryItem])
def get_public_categories(
    db: Session = Depends(get_db_session),
) -> list[CategoryItem]:
    return list_public_categories(db)


@public_router.get("/tags", response_model=list[TagItem])
def get_public_tags(
    db: Session = Depends(get_db_session),
) -> list[TagItem]:
    return list_public_tags(db)


@admin_router.get("/categories", response_model=list[CategoryItem])
def get_admin_categories(
    db: Session = Depends(get_db_session),
) -> list[CategoryItem]:
    return list_admin_categories(db)


@admin_router.post(
    "/categories",
    response_model=CategoryItem,
    status_code=status.HTTP_201_CREATED,
)
def post_category(
    payload: CategoryUpsertRequest,
    db: Session = Depends(get_db_session),
) -> CategoryItem:
    return create_category(db, payload)


@admin_router.put("/categories/{category_id}", response_model=CategoryItem)
def put_category(
    category_id: str,
    payload: CategoryUpsertRequest,
    db: Session = Depends(get_db_session),
) -> CategoryItem:
    return update_category(db, category_id, payload)


@admin_router.delete("/categories/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_category(
    category_id: str,
    db: Session = Depends(get_db_session),
) -> Response:
    delete_category(db, category_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@admin_router.get("/tags", response_model=list[TagItem])
def get_admin_tags(
    db: Session = Depends(get_db_session),
) -> list[TagItem]:
    return list_admin_tags(db)


@admin_router.post("/tags", response_model=TagItem, status_code=status.HTTP_201_CREATED)
def post_tag(
    payload: TagUpsertRequest,
    db: Session = Depends(get_db_session),
) -> TagItem:
    return create_tag(db, payload)


@admin_router.put("/tags/{tag_id}", response_model=TagItem)
def put_tag(
    tag_id: str,
    payload: TagUpsertRequest,
    db: Session = Depends(get_db_session),
) -> TagItem:
    return update_tag(db, tag_id, payload)


@admin_router.delete("/tags/{tag_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_tag(
    tag_id: str,
    db: Session = Depends(get_db_session),
) -> Response:
    delete_tag(db, tag_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
