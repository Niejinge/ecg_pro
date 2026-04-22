from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.modules.taxonomy import repository
from app.modules.taxonomy.models import Category, Tag
from app.modules.taxonomy.schemas import (
    CategoryItem,
    CategoryUpsertRequest,
    TagItem,
    TagUpsertRequest,
)


def _serialize_category(item: Category) -> CategoryItem:
    return CategoryItem(
        id=item.id,
        name=item.name,
        slug=item.slug,
        description=item.description,
        sort_order=item.sort_order,
        is_visible=item.is_visible,
        parent_id=item.parent_id,
    )


def _serialize_tag(item: Tag) -> TagItem:
    return TagItem(
        id=item.id,
        name=item.name,
        slug=item.slug,
        description=item.description,
    )


def list_public_categories(session: Session) -> list[CategoryItem]:
    return [_serialize_category(item) for item in repository.list_categories(session, only_visible=True)]


def list_admin_categories(session: Session) -> list[CategoryItem]:
    return [_serialize_category(item) for item in repository.list_categories(session)]


def create_category(session: Session, payload: CategoryUpsertRequest) -> CategoryItem:
    if repository.get_category_by_slug(session, payload.slug):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Category slug already exists.",
        )
    if payload.parent_id and repository.get_category(session, payload.parent_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Parent category not found.",
        )

    item = Category(**payload.model_dump())
    session.add(item)
    session.commit()
    session.refresh(item)
    return _serialize_category(item)


def update_category(
    session: Session,
    category_id: str,
    payload: CategoryUpsertRequest,
) -> CategoryItem:
    item = repository.get_category(session, category_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found.",
        )

    duplicate = repository.get_category_by_slug(session, payload.slug)
    if duplicate and duplicate.id != category_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Category slug already exists.",
        )
    if payload.parent_id and repository.get_category(session, payload.parent_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Parent category not found.",
        )

    for key, value in payload.model_dump().items():
        setattr(item, key, value)

    session.add(item)
    session.commit()
    session.refresh(item)
    return _serialize_category(item)


def delete_category(session: Session, category_id: str) -> None:
    item = repository.get_category(session, category_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found.",
        )

    session.delete(item)
    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Category cannot be deleted because it is still in use.",
        ) from exc


def list_public_tags(session: Session) -> list[TagItem]:
    return [_serialize_tag(item) for item in repository.list_tags(session)]


def list_admin_tags(session: Session) -> list[TagItem]:
    return [_serialize_tag(item) for item in repository.list_tags(session)]


def create_tag(session: Session, payload: TagUpsertRequest) -> TagItem:
    if repository.get_tag_by_slug(session, payload.slug):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tag slug already exists.",
        )

    item = Tag(**payload.model_dump())
    session.add(item)
    session.commit()
    session.refresh(item)
    return _serialize_tag(item)


def update_tag(session: Session, tag_id: str, payload: TagUpsertRequest) -> TagItem:
    item = repository.get_tag(session, tag_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tag not found.",
        )

    duplicate = repository.get_tag_by_slug(session, payload.slug)
    if duplicate and duplicate.id != tag_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tag slug already exists.",
        )

    for key, value in payload.model_dump().items():
        setattr(item, key, value)

    session.add(item)
    session.commit()
    session.refresh(item)
    return _serialize_tag(item)


def delete_tag(session: Session, tag_id: str) -> None:
    item = repository.get_tag(session, tag_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tag not found.",
        )

    session.delete(item)
    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tag cannot be deleted because it is still in use.",
        ) from exc

