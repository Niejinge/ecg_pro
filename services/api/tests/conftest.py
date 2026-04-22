from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.core import deps
from app.core.config import get_settings
from app.core.security import hash_password
from app.db.base import Base
from app.db.bootstrap import bootstrap_defaults
from app.db.models import import_models  # noqa: F401
from app.modules.users.models import Role, User


@pytest.fixture()
def db_session_factory(tmp_path, monkeypatch) -> Iterator[sessionmaker]:
    database_path = tmp_path / "test.db"
    storage_path = tmp_path / "storage"
    monkeypatch.setenv("LOCAL_STORAGE_PATH", str(storage_path))
    monkeypatch.setenv("PUBLIC_BASE_URL", "http://testserver")
    get_settings.cache_clear()

    engine = create_engine(
        f"sqlite:///{database_path}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(
        bind=engine,
        autoflush=False,
        autocommit=False,
        expire_on_commit=False,
    )

    monkeypatch.setattr(deps, "SessionLocal", testing_session_local)
    Base.metadata.create_all(bind=engine)

    with testing_session_local() as session:
        settings = get_settings()
        bootstrap_defaults(session, settings)

        student_role = session.scalar(select(Role).where(Role.code == "student"))
        existing_student = session.scalar(
            select(User).where(User.username == "student")
        )
        if existing_student is None:
            student = User(
                username="student",
                display_name="Student User",
                password_hash=hash_password("Student123456"),
                is_active=True,
                is_superuser=False,
                roles=[student_role] if student_role else [],
            )
            session.add(student)
            session.commit()

    yield testing_session_local

    Base.metadata.drop_all(bind=engine)
    engine.dispose()
    get_settings.cache_clear()


@pytest.fixture()
def client(db_session_factory) -> Iterator[TestClient]:
    from app.main import app

    with TestClient(app) as test_client:
        yield test_client


def _login(test_client: TestClient, username: str, password: str) -> str:
    response = test_client.post(
        "/api/v1/auth/login",
        json={"username": username, "password": password},
    )
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest.fixture()
def admin_headers(client: TestClient) -> dict[str, str]:
    token = _login(client, "admin", "Admin123456")
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def student_headers(client: TestClient) -> dict[str, str]:
    token = _login(client, "student", "Student123456")
    return {"Authorization": f"Bearer {token}"}
