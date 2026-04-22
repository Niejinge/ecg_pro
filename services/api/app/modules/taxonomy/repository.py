from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.taxonomy.models import Category, Tag


def list_categories(session: Session, *, only_visible: bool = False) -> list[Category]:
    statement = select(Category)
    if only_visible:
        statement = statement.where(Category.is_visible.is_(True))

    statement = statement.order_by(Category.sort_order.asc(), Category.name.asc())
    return list(session.scalars(statement).all())


def get_category(session: Session, category_id: str) -> Category | None:
    return session.get(Category, category_id)


def get_category_by_slug(session: Session, slug: str) -> Category | None:
    statement = select(Category).where(Category.slug == slug)
    return session.scalar(statement)


def list_tags(session: Session) -> list[Tag]:
    statement = select(Tag).order_by(Tag.name.asc())
    return list(session.scalars(statement).all())


def get_tag(session: Session, tag_id: str) -> Tag | None:
    return session.get(Tag, tag_id)


def get_tag_by_slug(session: Session, slug: str) -> Tag | None:
    statement = select(Tag).where(Tag.slug == slug)
    return session.scalar(statement)

