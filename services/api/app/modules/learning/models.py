from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.mixins import IdMixin, TimestampMixin
from app.domain.enums import LearningStatus


class LearningProgress(IdMixin, TimestampMixin, Base):
    __tablename__ = "learning_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "case_id", name="uq_learning_progress_user_case"),
    )

    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    case_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("ecg_cases.id", ondelete="CASCADE"),
    )
    status: Mapped[LearningStatus] = mapped_column(
        Enum(LearningStatus, name="learning_status", native_enum=False),
        default=LearningStatus.not_started,
        nullable=False,
    )
    completion_rate: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    best_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_viewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Favorite(IdMixin, TimestampMixin, Base):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("user_id", "case_id", name="uq_favorite_user_case"),)

    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    case_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("ecg_cases.id", ondelete="CASCADE"),
    )


class WrongQuestion(IdMixin, TimestampMixin, Base):
    __tablename__ = "wrong_questions"
    __table_args__ = (
        UniqueConstraint("user_id", "question_id", name="uq_wrong_question_user_question"),
    )

    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    question_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("quiz_questions.id", ondelete="CASCADE"),
    )
    wrong_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    last_wrong_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

