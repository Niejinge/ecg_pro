from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import IdMixin, TimestampMixin
from app.domain.enums import AttemptMode, DifficultyLevel, QuestionType


class QuizQuestion(IdMixin, TimestampMixin, Base):
    __tablename__ = "quiz_questions"

    case_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("ecg_cases.id", ondelete="CASCADE"),
    )
    stem: Mapped[str] = mapped_column(Text())
    explanation: Mapped[str | None] = mapped_column(Text())
    question_type: Mapped[QuestionType] = mapped_column(
        Enum(QuestionType, name="question_type", native_enum=False),
        default=QuestionType.single_choice,
        nullable=False,
    )
    difficulty: Mapped[DifficultyLevel] = mapped_column(
        Enum(DifficultyLevel, name="quiz_difficulty_level", native_enum=False),
        default=DifficultyLevel.beginner,
        nullable=False,
    )
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    case: Mapped["ECGCase"] = relationship(back_populates="quiz_questions")
    options: Mapped[list["QuizQuestionOption"]] = relationship(
        back_populates="question",
        cascade="all, delete-orphan",
    )
    attempt_items: Mapped[list["QuizAttemptItem"]] = relationship(
        back_populates="question",
    )


class QuizQuestionOption(IdMixin, TimestampMixin, Base):
    __tablename__ = "quiz_question_options"

    question_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("quiz_questions.id", ondelete="CASCADE"),
    )
    label: Mapped[str] = mapped_column(String(8))
    content: Mapped[str] = mapped_column(Text())
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    question: Mapped[QuizQuestion] = relationship(back_populates="options")


class QuizAttempt(IdMixin, TimestampMixin, Base):
    __tablename__ = "quiz_attempts"

    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    case_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("ecg_cases.id", ondelete="SET NULL"),
    )
    mode: Mapped[AttemptMode] = mapped_column(
        Enum(AttemptMode, name="attempt_mode", native_enum=False),
        default=AttemptMode.case_quiz,
        nullable=False,
    )
    score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_questions: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    correct_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    items: Mapped[list["QuizAttemptItem"]] = relationship(
        back_populates="attempt",
        cascade="all, delete-orphan",
    )


class QuizAttemptItem(IdMixin, TimestampMixin, Base):
    __tablename__ = "quiz_attempt_items"

    attempt_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("quiz_attempts.id", ondelete="CASCADE"),
    )
    question_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("quiz_questions.id", ondelete="CASCADE"),
    )
    selected_option_ids: Mapped[list[str]] = mapped_column(
        JSON,
        default=list,
        nullable=False,
    )
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    attempt: Mapped[QuizAttempt] = relationship(back_populates="items")
    question: Mapped[QuizQuestion] = relationship(back_populates="attempt_items")

