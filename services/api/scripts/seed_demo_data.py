from app.core.config import get_settings
from app.db.demo_seed import seed_demo_content
from app.db.models import import_models  # noqa: F401
from app.db.session import SessionLocal


def main() -> None:
    settings = get_settings()

    with SessionLocal() as session:
        summary = seed_demo_content(session, settings)

    print(
        "Demo seed ready: "
        f"{summary.categories} categories, "
        f"{summary.tags} tags, "
        f"{summary.cases} cases, "
        f"{summary.questions} questions, "
        f"{summary.images} images."
    )


if __name__ == "__main__":
    main()
