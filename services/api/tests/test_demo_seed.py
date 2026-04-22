from pathlib import Path

from sqlalchemy import select

from app.core.config import get_settings
from app.db.demo_seed import seed_demo_content
from app.modules.cases.models import ECGCase
from app.modules.quizzes.models import QuizQuestion
from app.modules.taxonomy.models import Category, Tag


def test_demo_seed_populates_repeatable_demo_content(db_session_factory) -> None:
    with db_session_factory() as session:
        settings = get_settings()

        first_summary = seed_demo_content(session, settings)
        second_summary = seed_demo_content(session, settings)

        assert first_summary == second_summary
        assert first_summary.categories == 3
        assert first_summary.tags == 5
        assert first_summary.cases == 4
        assert first_summary.questions == 8
        assert first_summary.images == 4

        categories = session.scalars(select(Category)).all()
        tags = session.scalars(select(Tag)).all()
        cases = session.scalars(select(ECGCase)).all()
        questions = session.scalars(select(QuizQuestion)).all()

        assert len(categories) == first_summary.categories
        assert len(tags) == first_summary.tags
        assert len(cases) == first_summary.cases
        assert len(questions) == first_summary.questions

        storage_root = Path(settings.local_storage_path)
        for ecg_case in cases:
            assert ecg_case.status.value == "published"
            assert ecg_case.published_at is not None
            assert len(ecg_case.images) == 1
            image = ecg_case.images[0]
            assert image.is_primary is True
            assert image.file_url.endswith(f"/api/v1/public/images/{image.id}/file")
            matching_files = list(
                (storage_root / "case-images" / ecg_case.id).glob(f"{image.id}_*")
            )
            assert len(matching_files) == 1
            assert matching_files[0].read_bytes()
