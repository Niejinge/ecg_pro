from app.core.config import get_settings
from app.db.models import import_models  # noqa: F401
from app.db.bootstrap import bootstrap_defaults
from app.db.session import SessionLocal


def main() -> None:
    settings = get_settings()

    with SessionLocal() as session:
        admin_user = bootstrap_defaults(session, settings)

    print(f"Bootstrap admin ready: {admin_user.username}")


if __name__ == "__main__":
    main()
