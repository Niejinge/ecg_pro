from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import hash_password
from app.modules.users.models import Role, User


def bootstrap_defaults(session: Session, settings: Settings) -> User:
    admin_role = session.scalar(select(Role).where(Role.code == "admin"))
    if admin_role is None:
        admin_role = Role(
            code="admin",
            name="Administrator",
            description="Full access to the ECG Pro admin console.",
        )
        session.add(admin_role)

    student_role = session.scalar(select(Role).where(Role.code == "student"))
    if student_role is None:
        student_role = Role(
            code="student",
            name="Student",
            description="Default role for end users of the ECG learning platform.",
        )
        session.add(student_role)

    session.flush()

    admin_user = session.scalar(
        select(User).where(User.username == settings.bootstrap_admin_username)
    )
    if admin_user is None:
        admin_user = User(
            username=settings.bootstrap_admin_username,
            display_name=settings.bootstrap_admin_display_name,
            password_hash=hash_password(settings.bootstrap_admin_password),
            is_active=True,
            is_superuser=True,
            roles=[admin_role],
        )
        session.add(admin_user)
        session.flush()

    if admin_role not in admin_user.roles:
        admin_user.roles.append(admin_role)

    session.commit()
    session.refresh(admin_user)
    return admin_user

