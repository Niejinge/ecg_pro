from __future__ import annotations

from base64 import b64decode
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import Settings
from app.db.bootstrap import bootstrap_defaults
from app.domain.enums import (
    CaseStatus,
    DifficultyLevel,
    QuestionType,
    RiskLevel,
)
from app.modules.cases.models import ECGCase, ECGCaseImage
from app.modules.quizzes.models import QuizQuestion, QuizQuestionOption
from app.modules.taxonomy.models import Category, Tag

DEMO_IMAGE_BYTES = b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg=="
)

DEMO_CATEGORIES = [
    {
        "name": "快速性心律失常",
        "slug": "tachy-arrhythmia",
        "description": "聚焦室上速、房扑、房颤等快速性心律失常识别与处理。",
        "sort_order": 1,
        "is_visible": True,
        "parent_id": None,
    },
    {
        "name": "心肌缺血与梗死",
        "slug": "ischemia-infarction",
        "description": "覆盖急性冠脉综合征和 ST-T 改变的教学案例。",
        "sort_order": 2,
        "is_visible": True,
        "parent_id": None,
    },
    {
        "name": "传导阻滞",
        "slug": "conduction-block",
        "description": "适合练习房室传导阻滞和起搏相关心电图。",
        "sort_order": 3,
        "is_visible": True,
        "parent_id": None,
    },
]

DEMO_TAGS = [
    {
        "name": "高危",
        "slug": "high-risk",
        "description": "存在较高临床风险，需要优先学习和复盘。",
    },
    {
        "name": "急诊处理",
        "slug": "emergency",
        "description": "强调急诊识别和初步处置流程。",
    },
    {
        "name": "抗凝评估",
        "slug": "anticoagulation",
        "description": "涉及卒中风险评估和抗凝决策。",
    },
    {
        "name": "起搏器相关",
        "slug": "pacemaker",
        "description": "需要结合起搏适应证和节律稳定性理解。",
    },
    {
        "name": "易错点",
        "slug": "pitfall",
        "description": "常见误判和鉴别诊断知识点。",
    },
]

DEMO_CASES = [
    {
        "case_code": "ECG-DEMO-001",
        "title": "室上性心动过速识别",
        "summary": "典型窄 QRS 规则性心动过速教学案例。",
        "diagnosis": "室上性心动过速",
        "rhythm_type": "规则快速心律",
        "heart_rate": "180 bpm",
        "axis_description": "电轴正常",
        "pr_description": "P 波与 QRS 关系不清",
        "qrs_description": "QRS 窄",
        "st_t_description": "可见继发性 ST-T 改变",
        "qt_description": "快速节律下 QT 评估受限",
        "key_leads": ["II", "V1"],
        "clinical_significance": "需要快速识别并与窦速、房扑进行区分。",
        "differential_diagnosis": "窦性心动过速、房扑 2:1 下传、室性心动过速",
        "treatment_plan": "先评估血流动力学稳定性，再考虑迷走刺激或腺苷。",
        "urgent_actions": "若不稳定，优先同步电复律。",
        "follow_up_recommendations": "建议进一步心电生理评估和诱因筛查。",
        "detailed_description": "患者突发心悸伴胸闷，心电图表现为规则窄 QRS 心动过速，P 波难以分辨。",
        "interpretation_steps": ["先看心率", "判断节律是否规则", "确认 QRS 是否增宽"],
        "learning_points": ["窄 QRS 规则性心动过速首先考虑 SVT", "稳定性评估决定处理策略"],
        "common_mistakes": ["把 SVT 误判为窦性心动过速", "未先判断患者是否血流动力学稳定"],
        "memory_tips": ["先看宽窄，再看规则性"],
        "difficulty": DifficultyLevel.intermediate,
        "risk_level": RiskLevel.high,
        "category_slug": "tachy-arrhythmia",
        "tag_slugs": ["high-risk", "emergency", "pitfall"],
        "is_featured": True,
        "image_file_name": "ecg-demo-001.png",
        "questions": [
            {
                "stem": "该案例最符合以下哪种心律？",
                "explanation": "规则窄 QRS 快速心律且 P 波不清，首先考虑室上性心动过速。",
                "question_type": QuestionType.single_choice,
                "difficulty": DifficultyLevel.intermediate,
                "sort_order": 1,
                "is_active": True,
                "options": [
                    {"label": "A", "content": "室上性心动过速", "is_correct": True, "sort_order": 1},
                    {"label": "B", "content": "窦性心动过速", "is_correct": False, "sort_order": 2},
                    {"label": "C", "content": "三度房室传导阻滞", "is_correct": False, "sort_order": 3},
                ],
            },
            {
                "stem": "患者血流动力学不稳定时的首选处理是？",
                "explanation": "不稳定快速心律优先同步电复律。",
                "question_type": QuestionType.single_choice,
                "difficulty": DifficultyLevel.intermediate,
                "sort_order": 2,
                "is_active": True,
                "options": [
                    {"label": "A", "content": "观察随访", "is_correct": False, "sort_order": 1},
                    {"label": "B", "content": "同步电复律", "is_correct": True, "sort_order": 2},
                    {"label": "C", "content": "单纯补液", "is_correct": False, "sort_order": 3},
                ],
            },
        ],
    },
    {
        "case_code": "ECG-DEMO-002",
        "title": "房颤伴快速心室率",
        "summary": "用于训练不规则窄 QRS 快速心律识别。",
        "diagnosis": "心房颤动伴快速心室率",
        "rhythm_type": "绝对不规则快速心律",
        "heart_rate": "145 bpm",
        "axis_description": "电轴大致正常",
        "pr_description": "无明确 PR 间期",
        "qrs_description": "QRS 窄",
        "st_t_description": "可有非特异性 ST-T 改变",
        "qt_description": "QT 受心率影响需校正评估",
        "key_leads": ["II", "V5"],
        "clinical_significance": "需要同时关注心率控制和血栓栓塞风险。",
        "differential_diagnosis": "房扑伴变传导、多源性房性心动过速",
        "treatment_plan": "根据稳定性决定复律或心率控制，并评估抗凝指征。",
        "urgent_actions": "伴胸痛、低血压或肺水肿时需紧急处理。",
        "follow_up_recommendations": "结合 CHA2DS2-VASc 评分评估长期抗凝方案。",
        "detailed_description": "患者心悸 2 天，心电图 RR 间期绝对不规则，无离散 P 波。",
        "interpretation_steps": ["判断 RR 是否绝对不规则", "寻找离散 P 波", "结合病史评估发作时间"],
        "learning_points": ["房颤的关键是绝对不规则", "节律处理前先评估卒中风险"],
        "common_mistakes": ["把房颤误判为房扑", "未评估抗凝需求就直接复律"],
        "memory_tips": ["看到绝对不规则，优先想到房颤"],
        "difficulty": DifficultyLevel.intermediate,
        "risk_level": RiskLevel.medium,
        "category_slug": "tachy-arrhythmia",
        "tag_slugs": ["anticoagulation", "pitfall"],
        "is_featured": False,
        "image_file_name": "ecg-demo-002.png",
        "questions": [
            {
                "stem": "房颤最典型的节律特征是？",
                "explanation": "房颤的 RR 间期通常表现为绝对不规则。",
                "question_type": QuestionType.single_choice,
                "difficulty": DifficultyLevel.beginner,
                "sort_order": 1,
                "is_active": True,
                "options": [
                    {"label": "A", "content": "绝对不规则 RR 间期", "is_correct": True, "sort_order": 1},
                    {"label": "B", "content": "规则 RR 间期", "is_correct": False, "sort_order": 2},
                    {"label": "C", "content": "固定 PR 延长", "is_correct": False, "sort_order": 3},
                ],
            },
            {
                "stem": "处理房颤患者时，以下哪项经常需要同步评估？",
                "explanation": "房颤处理不只看心率，还要评估血栓风险和抗凝适应证。",
                "question_type": QuestionType.single_choice,
                "difficulty": DifficultyLevel.intermediate,
                "sort_order": 2,
                "is_active": True,
                "options": [
                    {"label": "A", "content": "抗凝指征", "is_correct": True, "sort_order": 1},
                    {"label": "B", "content": "骨密度", "is_correct": False, "sort_order": 2},
                    {"label": "C", "content": "眼压", "is_correct": False, "sort_order": 3},
                ],
            },
        ],
    },
    {
        "case_code": "ECG-DEMO-003",
        "title": "急性前壁 STEMI",
        "summary": "训练 ST 段抬高型心肌梗死的快速识别。",
        "diagnosis": "急性前壁 ST 段抬高型心肌梗死",
        "rhythm_type": "窦性心律",
        "heart_rate": "92 bpm",
        "axis_description": "电轴正常",
        "pr_description": "PR 间期正常",
        "qrs_description": "QRS 时限正常",
        "st_t_description": "V1-V4 导联 ST 段弓背向上抬高",
        "qt_description": "QTc 轻度延长",
        "key_leads": ["V1", "V2", "V3", "V4"],
        "clinical_significance": "提示前壁急性闭塞性冠脉事件，需要立即启动再灌注流程。",
        "differential_diagnosis": "早复极、急性心包炎、Brugada 样改变",
        "treatment_plan": "尽快启动胸痛流程并完成再灌注治疗。",
        "urgent_actions": "尽快联络导管室，评估急诊 PCI。",
        "follow_up_recommendations": "住院期完善冠脉危险因素管理和二级预防教育。",
        "detailed_description": "患者突发持续性胸痛伴大汗，前胸导联出现连续性 ST 段抬高。",
        "interpretation_steps": ["确认相邻导联 ST 抬高", "结合症状判断是否急性冠脉闭塞", "排除伪差及非缺血性抬高"],
        "learning_points": ["连续前胸导联 ST 抬高高度提示前壁 STEMI", "再灌注时效性非常关键"],
        "common_mistakes": ["把广泛 ST 抬高误判为早复极", "未及时启动胸痛中心流程"],
        "memory_tips": ["胸痛加前胸导联 ST 抬高，要先当 STEMI 处理"],
        "difficulty": DifficultyLevel.advanced,
        "risk_level": RiskLevel.critical,
        "category_slug": "ischemia-infarction",
        "tag_slugs": ["high-risk", "emergency"],
        "is_featured": True,
        "image_file_name": "ecg-demo-003.png",
        "questions": [
            {
                "stem": "以下哪组导联 ST 抬高最支持前壁 STEMI？",
                "explanation": "V1-V4 连续 ST 抬高是前壁 STEMI 的经典表现之一。",
                "question_type": QuestionType.single_choice,
                "difficulty": DifficultyLevel.advanced,
                "sort_order": 1,
                "is_active": True,
                "options": [
                    {"label": "A", "content": "V1-V4", "is_correct": True, "sort_order": 1},
                    {"label": "B", "content": "II、III、aVF", "is_correct": False, "sort_order": 2},
                    {"label": "C", "content": "I、aVL", "is_correct": False, "sort_order": 3},
                ],
            },
            {
                "stem": "该病例最重要的下一步措施是？",
                "explanation": "对于疑似 STEMI，核心是尽快启动再灌注流程。",
                "question_type": QuestionType.single_choice,
                "difficulty": DifficultyLevel.advanced,
                "sort_order": 2,
                "is_active": True,
                "options": [
                    {"label": "A", "content": "门诊复查", "is_correct": False, "sort_order": 1},
                    {"label": "B", "content": "立即启动再灌注流程", "is_correct": True, "sort_order": 2},
                    {"label": "C", "content": "仅口服止痛药", "is_correct": False, "sort_order": 3},
                ],
            },
        ],
    },
    {
        "case_code": "ECG-DEMO-004",
        "title": "三度房室传导阻滞",
        "summary": "练习房室分离和缓慢逸搏心律判断。",
        "diagnosis": "三度房室传导阻滞",
        "rhythm_type": "缓慢逸搏心律",
        "heart_rate": "35 bpm",
        "axis_description": "电轴轻度左偏",
        "pr_description": "P 波与 QRS 无固定关系",
        "qrs_description": "QRS 可宽可窄，需结合逸搏起源",
        "st_t_description": "继发性 ST-T 改变",
        "qt_description": "QT 随心率减慢相对延长",
        "key_leads": ["II", "V1"],
        "clinical_significance": "存在晕厥和心源性休克风险，需要紧急评估起搏。",
        "differential_diagnosis": "高度房室传导阻滞、窦性停搏伴交界逸搏",
        "treatment_plan": "处理可逆病因并评估临时或永久起搏。",
        "urgent_actions": "如伴低灌注，需立即建立起搏支持。",
        "follow_up_recommendations": "完善病因学检查并评估永久起搏器适应证。",
        "detailed_description": "患者反复头晕黑蒙，心电图可见独立 P 波与缓慢 QRS 逸搏节律并存。",
        "interpretation_steps": ["观察 P-P 与 R-R 规律性", "确认 P 与 QRS 脱节", "判断逸搏节律来源"],
        "learning_points": ["房室分离是三度房室传导阻滞的核心特征", "症状性患者常需起搏支持"],
        "common_mistakes": ["把三度房室传导阻滞误判为单纯窦缓", "忽略低灌注表现"],
        "memory_tips": ["P 走 P 的，QRS 走 QRS 的，要想到完全性阻滞"],
        "difficulty": DifficultyLevel.advanced,
        "risk_level": RiskLevel.high,
        "category_slug": "conduction-block",
        "tag_slugs": ["high-risk", "pacemaker"],
        "is_featured": False,
        "image_file_name": "ecg-demo-004.png",
        "questions": [
            {
                "stem": "三度房室传导阻滞最关键的识别点是？",
                "explanation": "房室分离即 P 波与 QRS 无固定传导关系，是完全性房室阻滞核心特征。",
                "question_type": QuestionType.single_choice,
                "difficulty": DifficultyLevel.intermediate,
                "sort_order": 1,
                "is_active": True,
                "options": [
                    {"label": "A", "content": "房室分离", "is_correct": True, "sort_order": 1},
                    {"label": "B", "content": "PR 固定延长", "is_correct": False, "sort_order": 2},
                    {"label": "C", "content": "ST 段抬高", "is_correct": False, "sort_order": 3},
                ],
            },
            {
                "stem": "症状性完全性房室传导阻滞通常需要优先考虑什么？",
                "explanation": "出现低灌注或晕厥时，起搏支持往往是关键干预。",
                "question_type": QuestionType.single_choice,
                "difficulty": DifficultyLevel.advanced,
                "sort_order": 2,
                "is_active": True,
                "options": [
                    {"label": "A", "content": "单纯门诊观察", "is_correct": False, "sort_order": 1},
                    {"label": "B", "content": "建立起搏支持", "is_correct": True, "sort_order": 2},
                    {"label": "C", "content": "立即停用全部液体", "is_correct": False, "sort_order": 3},
                ],
            },
        ],
    },
]


@dataclass(frozen=True)
class DemoSeedSummary:
    categories: int
    tags: int
    cases: int
    questions: int
    images: int


def _storage_dir(settings: Settings, case_id: str) -> Path:
    storage_dir = Path(settings.local_storage_path) / "case-images" / case_id
    storage_dir.mkdir(parents=True, exist_ok=True)
    return storage_dir


def _build_file_url(settings: Settings, image_id: str) -> str:
    return f"{settings.public_base_url}{settings.api_v1_prefix}/public/images/{image_id}/file"


def _upsert_category(session: Session, payload: dict[str, object]) -> Category:
    category = session.scalar(select(Category).where(Category.slug == payload["slug"]))
    if category is None:
        category = Category(slug=str(payload["slug"]))
        session.add(category)

    category.name = str(payload["name"])
    category.description = payload["description"]
    category.sort_order = int(payload["sort_order"])
    category.is_visible = bool(payload["is_visible"])
    category.parent_id = payload["parent_id"]
    session.flush()
    return category


def _upsert_tag(session: Session, payload: dict[str, object]) -> Tag:
    tag = session.scalar(select(Tag).where(Tag.slug == payload["slug"]))
    if tag is None:
        tag = Tag(slug=str(payload["slug"]))
        session.add(tag)

    tag.name = str(payload["name"])
    tag.description = payload["description"]
    session.flush()
    return tag


def _load_case(session: Session, case_code: str) -> ECGCase | None:
    statement = (
        select(ECGCase)
        .options(
            selectinload(ECGCase.quiz_questions).selectinload(QuizQuestion.options),
            selectinload(ECGCase.images),
            selectinload(ECGCase.tags),
        )
        .where(ECGCase.case_code == case_code)
    )
    return session.scalar(statement)


def _sync_question_options(
    session: Session,
    question: QuizQuestion,
    options_payload: list[dict[str, object]],
) -> None:
    existing_by_label = {item.label: item for item in question.options}
    expected_labels = {str(item["label"]) for item in options_payload}

    for payload in options_payload:
        label = str(payload["label"])
        option = existing_by_label.get(label)
        if option is None:
            option = QuizQuestionOption(label=label)
            question.options.append(option)

        option.content = str(payload["content"])
        option.is_correct = bool(payload["is_correct"])
        option.sort_order = int(payload["sort_order"])
        session.add(option)

    for label, option in existing_by_label.items():
        if label not in expected_labels:
            session.delete(option)


def _sync_questions(
    session: Session,
    ecg_case: ECGCase,
    questions_payload: list[dict[str, object]],
) -> None:
    existing_by_sort_order = {item.sort_order: item for item in ecg_case.quiz_questions}
    expected_orders = {int(item["sort_order"]) for item in questions_payload}

    for payload in questions_payload:
        sort_order = int(payload["sort_order"])
        question = existing_by_sort_order.get(sort_order)
        if question is None:
            question = QuizQuestion(case_id=ecg_case.id, sort_order=sort_order)
            ecg_case.quiz_questions.append(question)

        question.stem = str(payload["stem"])
        question.explanation = payload["explanation"]
        question.question_type = payload["question_type"]
        question.difficulty = payload["difficulty"]
        question.sort_order = sort_order
        question.is_active = bool(payload["is_active"])
        session.add(question)
        _sync_question_options(session, question, list(payload["options"]))

    for sort_order, question in existing_by_sort_order.items():
        if sort_order not in expected_orders:
            session.delete(question)


def _sync_primary_image(
    session: Session,
    settings: Settings,
    ecg_case: ECGCase,
    file_name: str,
) -> None:
    image = next((item for item in ecg_case.images if item.file_name == file_name), None)
    if image is None:
        image = ECGCaseImage(
            case_id=ecg_case.id,
            file_name=file_name,
            file_url="",
            content_type="image/png",
            is_primary=True,
            sort_order=0,
        )
        ecg_case.images.append(image)
        session.flush()

    for item in ecg_case.images:
        item.is_primary = item.id == image.id

    image.file_name = file_name
    image.content_type = "image/png"
    image.file_url = _build_file_url(settings, image.id)
    image.sort_order = 0
    session.add(image)
    session.flush()

    storage_dir = _storage_dir(settings, ecg_case.id)
    for file_path in storage_dir.glob(f"{image.id}_*"):
        if file_path.is_file():
            file_path.unlink(missing_ok=True)

    file_path = storage_dir / f"{image.id}_{file_name}"
    file_path.write_bytes(DEMO_IMAGE_BYTES)


def _upsert_case(
    session: Session,
    settings: Settings,
    payload: dict[str, object],
    *,
    created_by: str,
    categories_by_slug: dict[str, Category],
    tags_by_slug: dict[str, Tag],
) -> ECGCase:
    ecg_case = _load_case(session, str(payload["case_code"]))
    if ecg_case is None:
        ecg_case = ECGCase(case_code=str(payload["case_code"]), created_by=created_by)
        session.add(ecg_case)

    ecg_case.title = str(payload["title"])
    ecg_case.summary = payload["summary"]
    ecg_case.diagnosis = str(payload["diagnosis"])
    ecg_case.rhythm_type = payload["rhythm_type"]
    ecg_case.heart_rate = payload["heart_rate"]
    ecg_case.axis_description = payload["axis_description"]
    ecg_case.pr_description = payload["pr_description"]
    ecg_case.qrs_description = payload["qrs_description"]
    ecg_case.st_t_description = payload["st_t_description"]
    ecg_case.qt_description = payload["qt_description"]
    ecg_case.key_leads = list(payload["key_leads"])
    ecg_case.clinical_significance = payload["clinical_significance"]
    ecg_case.differential_diagnosis = payload["differential_diagnosis"]
    ecg_case.treatment_plan = payload["treatment_plan"]
    ecg_case.urgent_actions = payload["urgent_actions"]
    ecg_case.follow_up_recommendations = payload["follow_up_recommendations"]
    ecg_case.detailed_description = payload["detailed_description"]
    ecg_case.interpretation_steps = list(payload["interpretation_steps"])
    ecg_case.learning_points = list(payload["learning_points"])
    ecg_case.common_mistakes = list(payload["common_mistakes"])
    ecg_case.memory_tips = list(payload["memory_tips"])
    ecg_case.difficulty = payload["difficulty"]
    ecg_case.risk_level = payload["risk_level"]
    ecg_case.category = categories_by_slug[str(payload["category_slug"])]
    ecg_case.tags = [tags_by_slug[slug] for slug in payload["tag_slugs"]]
    ecg_case.is_featured = bool(payload["is_featured"])
    ecg_case.status = CaseStatus.published
    ecg_case.published_at = ecg_case.published_at or datetime.now(timezone.utc)
    session.add(ecg_case)
    session.flush()

    _sync_primary_image(session, settings, ecg_case, str(payload["image_file_name"]))
    _sync_questions(session, ecg_case, list(payload["questions"]))
    return ecg_case


def seed_demo_content(session: Session, settings: Settings) -> DemoSeedSummary:
    admin_user = bootstrap_defaults(session, settings)

    categories_by_slug = {
        item["slug"]: _upsert_category(session, item) for item in DEMO_CATEGORIES
    }
    tags_by_slug = {item["slug"]: _upsert_tag(session, item) for item in DEMO_TAGS}

    for payload in DEMO_CASES:
        _upsert_case(
            session,
            settings,
            payload,
            created_by=admin_user.id,
            categories_by_slug=categories_by_slug,
            tags_by_slug=tags_by_slug,
        )

    session.commit()
    return DemoSeedSummary(
        categories=len(DEMO_CATEGORIES),
        tags=len(DEMO_TAGS),
        cases=len(DEMO_CASES),
        questions=sum(len(item["questions"]) for item in DEMO_CASES),
        images=len(DEMO_CASES),
    )
