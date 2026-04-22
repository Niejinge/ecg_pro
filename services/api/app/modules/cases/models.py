from datetime import datetime

from sqlalchemy import (
    Column,
    JSON,
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Table,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import IdMixin, TimestampMixin
from app.domain.enums import CaseStatus, DifficultyLevel, RiskLevel

ecg_case_tags = Table(
    "ecg_case_tags",
    Base.metadata,
    Column(
        "case_id",
        String(36),
        ForeignKey("ecg_cases.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "tag_id",
        String(36),
        ForeignKey("tags.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)


class ECGCase(IdMixin, TimestampMixin, Base):
    __tablename__ = "ecg_cases"

    case_code: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(255), index=True)
    summary: Mapped[str | None] = mapped_column(Text())
    diagnosis: Mapped[str] = mapped_column(String(255), index=True)
    rhythm_type: Mapped[str | None] = mapped_column(String(128))
    heart_rate: Mapped[str | None] = mapped_column(String(64))
    axis_description: Mapped[str | None] = mapped_column(Text())
    pr_description: Mapped[str | None] = mapped_column(Text())
    qrs_description: Mapped[str | None] = mapped_column(Text())
    st_t_description: Mapped[str | None] = mapped_column(Text())
    qt_description: Mapped[str | None] = mapped_column(Text())
    key_leads: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    clinical_significance: Mapped[str | None] = mapped_column(Text())
    differential_diagnosis: Mapped[str | None] = mapped_column(Text())
    treatment_plan: Mapped[str | None] = mapped_column(Text())
    urgent_actions: Mapped[str | None] = mapped_column(Text())
    follow_up_recommendations: Mapped[str | None] = mapped_column(Text())
    detailed_description: Mapped[str | None] = mapped_column(Text())
    interpretation_steps: Mapped[list[str]] = mapped_column(
        JSON,
        default=list,
        nullable=False,
    )
    learning_points: Mapped[list[str]] = mapped_column(
        JSON,
        default=list,
        nullable=False,
    )
    common_mistakes: Mapped[list[str]] = mapped_column(
        JSON,
        default=list,
        nullable=False,
    )
    memory_tips: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    difficulty: Mapped[DifficultyLevel] = mapped_column(
        Enum(DifficultyLevel, name="difficulty_level", native_enum=False),
        default=DifficultyLevel.beginner,
        nullable=False,
    )
    risk_level: Mapped[RiskLevel] = mapped_column(
        Enum(RiskLevel, name="risk_level", native_enum=False),
        default=RiskLevel.low,
        nullable=False,
    )
    status: Mapped[CaseStatus] = mapped_column(
        Enum(CaseStatus, name="case_status", native_enum=False),
        default=CaseStatus.draft,
        nullable=False,
    )
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    category_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("categories.id", ondelete="SET NULL"),
    )
    created_by: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
    )

    category: Mapped["Category | None"] = relationship(back_populates="cases")
    creator: Mapped["User | None"] = relationship(back_populates="created_cases")
    tags: Mapped[list["Tag"]] = relationship(
        secondary=ecg_case_tags,
        back_populates="cases",
    )
    images: Mapped[list["ECGCaseImage"]] = relationship(
        back_populates="case",
        cascade="all, delete-orphan",
    )
    quiz_questions: Mapped[list["QuizQuestion"]] = relationship(
        back_populates="case",
        cascade="all, delete-orphan",
    )


class ECGCaseImage(IdMixin, TimestampMixin, Base):
    __tablename__ = "ecg_case_images"

    case_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("ecg_cases.id", ondelete="CASCADE"),
    )
    file_name: Mapped[str] = mapped_column(String(255))
    file_url: Mapped[str] = mapped_column(String(512))
    content_type: Mapped[str | None] = mapped_column(String(128))
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    case: Mapped[ECGCase] = relationship(back_populates="images")
