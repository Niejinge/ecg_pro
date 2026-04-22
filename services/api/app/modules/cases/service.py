from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.domain.enums import CaseStatus, DifficultyLevel, RiskLevel
from app.modules.cases import repository
from app.modules.cases.models import ECGCase
from app.modules.cases.schemas import (
    AdminCaseListItem,
    AdminCaseListResponse,
    AdminCaseUpsertRequest,
    CaseListResponse,
    CaseCategorySummary,
    CaseDetailItem,
    CaseImageItem,
    CaseListItem,
    CaseTagSummary,
)
from app.modules.taxonomy.models import Category, Tag
from app.modules.users.models import User


def _serialize_case_summary(item: ECGCase) -> CaseListItem:
    return CaseListItem(
        id=item.id,
        case_code=item.case_code,
        title=item.title,
        diagnosis=item.diagnosis,
        difficulty=item.difficulty,
        risk_level=item.risk_level,
        category_name=item.category.name if item.category else None,
    )


def _serialize_admin_case_summary(item: ECGCase) -> AdminCaseListItem:
    return AdminCaseListItem(
        **_serialize_case_summary(item).model_dump(),
        status=item.status,
        is_featured=item.is_featured,
        updated_at=item.updated_at,
    )


def _serialize_case_detail(item: ECGCase) -> CaseDetailItem:
    return CaseDetailItem(
        id=item.id,
        case_code=item.case_code,
        title=item.title,
        summary=item.summary,
        diagnosis=item.diagnosis,
        rhythm_type=item.rhythm_type,
        heart_rate=item.heart_rate,
        axis_description=item.axis_description,
        pr_description=item.pr_description,
        qrs_description=item.qrs_description,
        st_t_description=item.st_t_description,
        qt_description=item.qt_description,
        key_leads=item.key_leads,
        clinical_significance=item.clinical_significance,
        differential_diagnosis=item.differential_diagnosis,
        treatment_plan=item.treatment_plan,
        urgent_actions=item.urgent_actions,
        follow_up_recommendations=item.follow_up_recommendations,
        detailed_description=item.detailed_description,
        interpretation_steps=item.interpretation_steps,
        learning_points=item.learning_points,
        common_mistakes=item.common_mistakes,
        memory_tips=item.memory_tips,
        difficulty=item.difficulty,
        risk_level=item.risk_level,
        status=item.status,
        is_featured=item.is_featured,
        published_at=item.published_at,
        category=CaseCategorySummary(
            id=item.category.id,
            name=item.category.name,
            slug=item.category.slug,
        )
        if item.category
        else None,
        tags=[
            CaseTagSummary(id=tag.id, name=tag.name, slug=tag.slug)
            for tag in item.tags
        ],
        images=[
            CaseImageItem(
                id=image.id,
                file_name=image.file_name,
                file_url=image.file_url,
                content_type=image.content_type,
                is_primary=image.is_primary,
                sort_order=image.sort_order,
            )
            for image in sorted(item.images, key=lambda image: (image.sort_order, image.created_at))
        ],
        created_by=item.created_by,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


def _resolve_category(session: Session, category_id: str | None) -> Category | None:
    if category_id is None:
        return None

    category = session.get(Category, category_id)
    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found.",
        )
    return category


def _resolve_tags(session: Session, tag_ids: list[str]) -> list[Tag]:
    tags = [session.get(Tag, tag_id) for tag_id in tag_ids]
    if any(tag is None for tag in tags):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="One or more tags were not found.",
        )
    return [tag for tag in tags if tag is not None]


def list_public_cases(
    session: Session,
    *,
    keyword: str | None,
    category_id: str | None,
    tag_id: str | None,
    difficulty: DifficultyLevel | None,
    risk_level: RiskLevel | None,
    is_featured: bool | None,
    page: int,
    page_size: int,
) -> CaseListResponse:
    items, total = repository.list_cases(
        session,
        repository.CaseQueryFilters(
            keyword=keyword,
            category_id=category_id,
            tag_id=tag_id,
            difficulty=difficulty.value if difficulty else None,
            risk_level=risk_level.value if risk_level else None,
            is_featured=is_featured,
            page=page,
            page_size=page_size,
        ),
        public_only=True,
    )
    serialized_items = [_serialize_case_summary(item) for item in items]
    return CaseListResponse(
        items=serialized_items,
        total=total,
        page=page,
        page_size=page_size,
        has_next=page * page_size < total,
    )


def list_admin_cases(
    session: Session,
    *,
    keyword: str | None,
    category_id: str | None,
    tag_id: str | None,
    difficulty: DifficultyLevel | None,
    risk_level: RiskLevel | None,
    status: CaseStatus | None,
    is_featured: bool | None,
    page: int,
    page_size: int,
) -> AdminCaseListResponse:
    items, total = repository.list_cases(
        session,
        repository.CaseQueryFilters(
            keyword=keyword,
            category_id=category_id,
            tag_id=tag_id,
            difficulty=difficulty.value if difficulty else None,
            risk_level=risk_level.value if risk_level else None,
            status=status.value if status else None,
            is_featured=is_featured,
            page=page,
            page_size=page_size,
        ),
        public_only=False,
    )
    serialized_items = [_serialize_admin_case_summary(item) for item in items]
    return AdminCaseListResponse(
        items=serialized_items,
        total=total,
        page=page,
        page_size=page_size,
        has_next=page * page_size < total,
    )


def get_public_case_detail(session: Session, case_id: str) -> CaseDetailItem:
    item = repository.get_case(session, case_id)
    if item is None or item.status != CaseStatus.published:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Published case not found.",
        )
    return _serialize_case_detail(item)


def get_admin_case_detail(session: Session, case_id: str) -> CaseDetailItem:
    item = repository.get_case(session, case_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )
    return _serialize_case_detail(item)


def create_case(
    session: Session,
    payload: AdminCaseUpsertRequest,
    current_user: User,
) -> CaseDetailItem:
    if repository.get_case_by_code(session, payload.case_code):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Case code already exists.",
        )

    item = ECGCase(
        **payload.model_dump(exclude={"tag_ids"}),
        status=CaseStatus.draft,
        created_by=current_user.id,
    )
    item.category = _resolve_category(session, payload.category_id)
    item.tags = _resolve_tags(session, payload.tag_ids)

    session.add(item)
    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Case could not be created due to a conflicting record.",
        ) from exc
    session.refresh(item)
    return get_admin_case_detail(session, item.id)


def update_case(
    session: Session,
    case_id: str,
    payload: AdminCaseUpsertRequest,
) -> CaseDetailItem:
    item = repository.get_case(session, case_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )

    duplicate = repository.get_case_by_code(session, payload.case_code)
    if duplicate and duplicate.id != case_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Case code already exists.",
        )

    for key, value in payload.model_dump(exclude={"tag_ids"}).items():
        setattr(item, key, value)

    item.category = _resolve_category(session, payload.category_id)
    item.tags = _resolve_tags(session, payload.tag_ids)

    session.add(item)
    session.commit()
    session.refresh(item)
    return get_admin_case_detail(session, item.id)


def delete_case(session: Session, case_id: str) -> None:
    item = repository.get_case(session, case_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )
    session.delete(item)
    session.commit()


def publish_case(session: Session, case_id: str) -> CaseDetailItem:
    item = repository.get_case(session, case_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )

    item.status = CaseStatus.published
    if item.published_at is None:
        item.published_at = datetime.now(timezone.utc)

    session.add(item)
    session.commit()
    session.refresh(item)
    return get_admin_case_detail(session, item.id)


def offline_case(session: Session, case_id: str) -> CaseDetailItem:
    item = repository.get_case(session, case_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )

    item.status = CaseStatus.offline
    session.add(item)
    session.commit()
    session.refresh(item)
    return get_admin_case_detail(session, item.id)
