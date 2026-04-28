"""
General ECG PDF extractor.

The extractor supports two common source types:
- text PDFs: use the native PDF text layer;
- scanned PDFs: render page images and optionally OCR them with Tesseract.

Outputs are draft datasets for manual review, not final clinical truth.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_PDF_DIR = r"D:\心电图学习\学习"
DEFAULT_OUTPUT_ROOT = Path(__file__).resolve().parent / "output"
COMMON_TESSERACT_PATHS = [
    r"C:\Program Files\Tesseract-OCR\tesseract.exe",
    r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
]

ECG_KEYWORD_MAP: dict[str, list[str]] = {
    "窦性心律": ["窦性心律", "sinus rhythm"],
    "窦性心动过缓": ["窦性心动过缓", "心动过缓", "bradycardia"],
    "窦性心动过速": ["窦性心动过速", "sinus tachycardia"],
    "房性早搏": ["房性早搏", "房早", "PAC"],
    "室性早搏": ["室性早搏", "室早", "PVC"],
    "房颤": ["房颤", "心房颤动", "atrial fibrillation"],
    "房扑": ["房扑", "心房扑动", "atrial flutter"],
    "室上速": ["室上性心动过速", "室上速", "SVT"],
    "室速": ["室性心动过速", "室速", "VT"],
    "室颤": ["室颤", "心室颤动", "VF"],
    "房室传导阻滞": ["房室传导阻滞", "AV block", "AVB"],
    "左束支阻滞": ["左束支", "LBBB"],
    "右束支阻滞": ["右束支", "RBBB"],
    "ST段抬高": ["ST段抬高", "ST抬高", "STEMI"],
    "ST段压低": ["ST段压低", "ST压低"],
    "心肌梗死": ["心肌梗死", "心梗", "myocardial infarction"],
    "预激综合征": ["预激", "WPW"],
    "长QT": ["长QT", "QT延长", "long QT"],
    "高钾血症": ["高钾", "高钾血症", "hyperkalemia"],
    "低钾血症": ["低钾", "低钾血症", "hypokalemia"],
}

CRITICAL_TERMS = ["室颤", "VF", "STEMI", "ST段抬高型心肌梗死", "急性心肌梗死", "尖端扭转", "心脏骤停"]
HIGH_RISK_TERMS = ["室速", "VT", "三度房室传导阻滞", "高钾", "心肌梗死", "ST段抬高"]
MEDIUM_RISK_TERMS = ["房颤", "房扑", "室上速", "二度房室传导阻滞", "ST段压低"]

CASE_MARKER_RE = re.compile(
    r"(?:^|\n)\s*((?:病例|案例|例|Case)\s*[\d一二三四五六七八九十百]+[^\n]*)",
    re.IGNORECASE,
)
CHAPTER_LINE_RE = re.compile(
    r"^(?:第\s*[\d一二三四五六七八九十百]+\s*[章节篇]|Chapter\s+\d+)\b.*",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class OcrResult:
    text: str
    status: str
    error: str | None = None


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def safe_slug(value: str, fallback: str = "ecg_pdf") -> str:
    cleaned = re.sub(r"[^\w\u4e00-\u9fff-]+", "_", value, flags=re.UNICODE)
    cleaned = cleaned.strip("._-")
    return cleaned[:80] or fallback


def normalize_ocr_text(text: str) -> str:
    """Reduce OCR spacing noise while preserving line boundaries for headings."""
    if not text:
        return ""

    normalized_lines = []
    for raw_line in text.replace("\u3000", " ").splitlines():
        line = re.sub(r"[ \t]+", " ", raw_line).strip()
        line = re.sub(r"(?<=[\u4e00-\u9fff])\s+(?=[\u4e00-\u9fff])", "", line)
        line = re.sub(r"(?<=[\u4e00-\u9fff])\s+(?=[，。；：、])", "", line)
        line = re.sub(r"(?<=[，。；：、])\s+(?=[\u4e00-\u9fff])", "", line)
        normalized_lines.append(line)
    return "\n".join(normalized_lines).strip()


def find_pdf(keyword: str | None = None, exact_path: str | None = None) -> str | None:
    if exact_path and Path(exact_path).exists():
        return exact_path

    root_dir = Path(DEFAULT_PDF_DIR)
    if not root_dir.exists():
        return None

    for path in root_dir.rglob("*.pdf"):
        if keyword is None or keyword in path.name:
            return str(path)
    return None


def load_pdf_runtime():
    try:
        import fitz  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "缺少 PyMuPDF 依赖。请先安装: python -m pip install pymupdf pillow"
        ) from exc
    return fitz


def detect_keywords(text: str) -> list[str]:
    if not text:
        return []

    lower = text.lower()
    found: list[str] = []
    for label, terms in ECG_KEYWORD_MAP.items():
        if any(term.lower() in lower for term in terms):
            found.append(label)
    return found


def infer_risk_level(text: str, keywords: list[str]) -> str:
    joined = f"{text}\n{' '.join(keywords)}"
    lower = joined.lower()
    if any(term.lower() in lower for term in CRITICAL_TERMS):
        return "critical"
    if any(term.lower() in lower for term in HIGH_RISK_TERMS):
        return "high"
    if any(term.lower() in lower for term in MEDIUM_RISK_TERMS):
        return "medium"
    return "low"


def infer_difficulty(text: str, risk_level: str, keywords: list[str]) -> str:
    if risk_level in {"critical", "high"}:
        return "advanced"
    if len(keywords) >= 2 or any(term in text for term in ["鉴别", "复杂", "合并"]):
        return "intermediate"
    return "beginner"


def infer_diagnosis(text: str, keywords: list[str]) -> str:
    for prefix in ["诊断", "心电图诊断", "答案", "印象"]:
        match = re.search(rf"{prefix}\s*[:：]\s*([^\n。；;]+)", text)
        if match:
            return match.group(1).strip()[:255]
    return keywords[0] if keywords else "待人工判读"


def extract_short_field(text: str, labels: list[str], limit: int = 500) -> str | None:
    for label in labels:
        match = re.search(rf"{label}\s*[:：]\s*([^\n]+(?:\n(?!\S+[:：]).+)*)", text)
        if match:
            return re.sub(r"\s+", " ", match.group(1)).strip()[:limit]
    return None


def extract_patient_info(text: str) -> dict[str, Any]:
    age = None
    gender = None

    age_match = re.search(r"(\d{1,3})\s*岁", text)
    if age_match:
        age = int(age_match.group(1))

    if re.search(r"\b男\b|男性|男患", text):
        gender = "male"
    elif re.search(r"\b女\b|女性|女患", text):
        gender = "female"

    return {"patient_age": age, "patient_gender": gender}


def find_case_marker(text: str) -> str | None:
    match = CASE_MARKER_RE.search(text or "")
    return match.group(1).strip() if match else None


def find_chapter_marker(text: str) -> str | None:
    lines = [line.strip() for line in (text or "").splitlines() if line.strip()]
    for index, line in enumerate(lines):
        if not CHAPTER_LINE_RE.match(line):
            continue
        marker = line
        if index + 1 < len(lines):
            next_line = lines[index + 1].strip()
            if 2 <= len(next_line) <= 40 and not CHAPTER_LINE_RE.match(next_line):
                marker = f"{marker} {next_line}"
        return marker[:80]
    return None


def discover_tesseract_cmd(explicit_cmd: str | None = None) -> str | None:
    if explicit_cmd and Path(explicit_cmd).exists():
        return explicit_cmd

    path_cmd = shutil.which("tesseract")
    if path_cmd:
        return path_cmd

    for candidate in COMMON_TESSERACT_PATHS:
        if Path(candidate).exists():
            return candidate
    return None


def is_tesseract_available(explicit_cmd: str | None = None) -> bool:
    return discover_tesseract_cmd(explicit_cmd) is not None


def ocr_page(image_path: Path, lang: str, tesseract_cmd: str | None = None) -> OcrResult:
    command = discover_tesseract_cmd(tesseract_cmd)
    if not command:
        return OcrResult("", "unavailable", "tesseract executable not found in PATH")

    try:
        import pytesseract  # type: ignore
        from PIL import Image  # type: ignore
    except ImportError as exc:
        return OcrResult("", "unavailable", f"OCR python dependency missing: {exc}")

    pytesseract.pytesseract.tesseract_cmd = command
    try:
        text = pytesseract.image_to_string(Image.open(image_path), lang=lang)
    except Exception as exc:  # pragma: no cover - depends on local OCR install
        return OcrResult("", "failed", str(exc))
    return OcrResult(text.strip(), "ok")


def render_page(page: Any, page_image_path: Path, render_dpi: int) -> dict[str, int]:
    fitz = load_pdf_runtime()
    mat = fitz.Matrix(render_dpi / 72, render_dpi / 72)
    pix = page.get_pixmap(matrix=mat, alpha=False)
    pix.save(str(page_image_path))
    return {"width": pix.width, "height": pix.height}


def extract_embedded_images(doc: Any, page: Any, page_number: int, images_dir: Path) -> list[dict[str, Any]]:
    fitz = load_pdf_runtime()
    embedded_images: list[dict[str, Any]] = []

    for index, image_info in enumerate(page.get_images(full=True)):
        xref = image_info[0]
        try:
            image_pix = fitz.Pixmap(doc, xref)
            if image_pix.n >= 5:
                image_pix = fitz.Pixmap(fitz.csRGB, image_pix)
            image_name = f"page_{page_number:04d}_img_{index:02d}.png"
            image_path = images_dir / image_name
            image_pix.save(str(image_path))
            embedded_images.append(
                {
                    "filename": image_name,
                    "relative_path": f"images/{image_name}",
                    "width": image_pix.width,
                    "height": image_pix.height,
                    "is_ecg_waveform": image_pix.width >= 500 or image_pix.height >= 250,
                }
            )
        except Exception as exc:
            embedded_images.append(
                {
                    "filename": None,
                    "relative_path": None,
                    "error": str(exc),
                    "is_ecg_waveform": False,
                }
            )
    return embedded_images


def should_ocr_page(native_text: str, ocr_mode: str) -> bool:
    if ocr_mode == "off":
        return False
    if ocr_mode == "force":
        return True
    return len(native_text.strip()) < 30


def extract_pdf(
    pdf_path: str,
    output_base: str | Path,
    render_dpi: int = 220,
    max_pages: int | None = None,
    ocr_mode: str = "auto",
    ocr_lang: str = "chi_sim+eng",
    tesseract_cmd: str | None = None,
    case_page_span: int = 2,
    grouping: str = "auto",
    case_prefix: str = "ECG-BOOK",
    book_title: str | None = None,
) -> dict[str, Any]:
    fitz = load_pdf_runtime()
    pdf_file = Path(pdf_path)
    output_path = Path(output_base)
    pages_dir = output_path / "pages"
    images_dir = output_path / "images"
    ensure_dir(pages_dir)
    ensure_dir(images_dir)

    doc = fitz.open(str(pdf_file))
    pdf_metadata = doc.metadata or {}
    total_pages = doc.page_count
    pages_to_process = min(total_pages, max_pages) if max_pages else total_pages
    title = book_title or (pdf_metadata.get("title") or pdf_file.stem).replace("\x00", "").strip()

    print(f"Processing: {pdf_file.name}")
    print(f"Pages: {pages_to_process}/{total_pages}")
    detected_tesseract = discover_tesseract_cmd(tesseract_cmd)
    print(f"OCR mode: {ocr_mode} ({detected_tesseract or 'unavailable'})")

    pages: list[dict[str, Any]] = []
    ocr_status_counts: dict[str, int] = {}

    for page_index in range(pages_to_process):
        page_number = page_index + 1
        if page_number == 1 or page_number % 20 == 0 or page_number == pages_to_process:
            print(f"  Page {page_number}/{pages_to_process}")

        page = doc[page_index]
        page_image_name = f"page_{page_number:04d}.png"
        page_image_path = pages_dir / page_image_name
        rendered = render_page(page, page_image_path, render_dpi)

        native_text = page.get_text("text").strip()
        ocr_result = OcrResult("", "skipped")
        if should_ocr_page(native_text, ocr_mode):
            ocr_result = ocr_page(page_image_path, ocr_lang, detected_tesseract)
        ocr_status_counts[ocr_result.status] = ocr_status_counts.get(ocr_result.status, 0) + 1

        page_text = native_text if native_text else ocr_result.text
        normalized_text = normalize_ocr_text(page_text)
        keywords = detect_keywords(normalized_text)
        embedded_images = extract_embedded_images(doc, page, page_number, images_dir)

        pages.append(
            {
                "page_number": page_number,
                "page_image_path": f"pages/{page_image_name}",
                "page_image_width": rendered["width"],
                "page_image_height": rendered["height"],
                "native_text": native_text,
                "ocr_text": ocr_result.text,
                "ocr_status": ocr_result.status,
                "ocr_error": ocr_result.error,
                "text": page_text,
                "normalized_text": normalized_text,
                "has_native_text": len(native_text) >= 30,
                "has_ocr_text": bool(ocr_result.text),
                "is_scanned_page": len(native_text) < 30,
                "case_marker": find_case_marker(normalized_text),
                "chapter_marker": find_chapter_marker(normalized_text),
                "ecg_keywords": keywords,
                "embedded_images": embedded_images,
                "total_embedded_images": len(embedded_images),
            }
        )

    doc.close()

    cases = group_into_cases(
        pages=pages,
        case_page_span=case_page_span,
        grouping=grouping,
        case_prefix=case_prefix,
        source_book=title,
    )

    result = {
        "source": {
            "filename": pdf_file.name,
            "full_path": str(pdf_file),
            "book_title": title,
            "metadata": pdf_metadata,
            "total_pages": total_pages,
            "pages_processed": pages_to_process,
            "extraction_date": datetime.now().isoformat(timespec="seconds"),
            "extraction_method": "PyMuPDF native text + rendered pages + optional OCR",
            "render_dpi": render_dpi,
            "ocr_mode": ocr_mode,
            "ocr_language": ocr_lang,
            "tesseract_cmd": detected_tesseract,
        },
        "summary": {
            "total_pages": total_pages,
            "pages_processed": pages_to_process,
            "pages_with_native_text": sum(1 for page in pages if page["has_native_text"]),
            "pages_with_ocr_text": sum(1 for page in pages if page["has_ocr_text"]),
            "pages_scanned_or_image_only": sum(1 for page in pages if page["is_scanned_page"]),
            "pages_with_case_numbers": sum(1 for page in pages if page["case_marker"]),
            "total_embedded_images": sum(page["total_embedded_images"] for page in pages),
            "total_cases_grouped": len(cases),
            "ocr_status_counts": ocr_status_counts,
            "grouping_strategy": infer_grouping_strategy(pages, grouping),
        },
        "cases": cases,
        "admin_import_payloads": [case["platform_payload"] for case in cases],
        "pages": pages,
    }

    write_outputs(result, output_path)
    return result


def group_into_cases(
    pages: list[dict[str, Any]],
    case_page_span: int,
    grouping: str,
    case_prefix: str,
    source_book: str,
) -> list[dict[str, Any]]:
    if not pages:
        return []

    cases: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] = []
    strategy = infer_grouping_strategy(pages, grouping)

    if strategy == "case":
        for page in pages:
            if page.get("case_marker") and current:
                cases.append(current)
                current = []
            current.append(page)
        if current:
            cases.append(current)
    elif strategy == "chapter":
        for page in pages:
            if page.get("chapter_marker") and current:
                cases.append(current)
                current = []
            current.append(page)
        if current:
            cases.append(current)
    else:
        span = max(1, case_page_span)
        for start in range(0, len(pages), span):
            cases.append(pages[start : start + span])

    return [
        build_case(index, case_pages, case_prefix=case_prefix, source_book=source_book)
        for index, case_pages in enumerate(cases, start=1)
    ]


def infer_grouping_strategy(pages: list[dict[str, Any]], requested: str) -> str:
    if requested != "auto":
        return requested

    case_markers = sum(1 for page in pages if page.get("case_marker"))
    chapter_markers = sum(1 for page in pages if page.get("chapter_marker"))
    if case_markers >= 2:
        return "case"
    if chapter_markers >= 2:
        return "chapter"
    return "fixed"


def build_case(
    case_index: int,
    pages: list[dict[str, Any]],
    case_prefix: str,
    source_book: str,
) -> dict[str, Any]:
    page_numbers = [page["page_number"] for page in pages]
    combined_text = "\n".join(
        page.get("normalized_text") or page.get("text") or "" for page in pages
    ).strip()
    native_text = "\n".join(page.get("native_text") or "" for page in pages).strip()
    ocr_text = "\n".join(page.get("ocr_text") or "" for page in pages).strip()

    keywords: list[str] = []
    for page in pages:
        for keyword in page.get("ecg_keywords", []):
            if keyword not in keywords:
                keywords.append(keyword)

    chapter_name = next((page.get("chapter_marker") for page in pages if page.get("chapter_marker")), None)
    case_marker = next((page.get("case_marker") for page in pages if page.get("case_marker")), None)
    is_case_like_record = bool(case_marker)
    diagnosis = infer_diagnosis(combined_text, keywords) if is_case_like_record else "待人工判读"
    risk_level = infer_risk_level(combined_text, keywords) if is_case_like_record else "low"
    difficulty = infer_difficulty(combined_text, risk_level, keywords)
    patient_info = extract_patient_info(combined_text)

    page_range = (
        f"{page_numbers[0]}-{page_numbers[-1]}"
        if page_numbers and page_numbers[0] != page_numbers[-1]
        else str(page_numbers[0])
    )
    title_seed = case_marker or chapter_name or diagnosis
    title = f"{source_book} 病例 {case_index:03d}"
    if title_seed and title_seed != "待人工判读":
        title = f"{title} - {title_seed[:40]}"

    embedded_images = [
        image
        for page in pages
        for image in page.get("embedded_images", [])
        if image.get("relative_path")
    ]
    image_candidates = [
        {
            "relative_path": page["page_image_path"],
            "source": "rendered_page",
            "page_number": page["page_number"],
            "is_primary": index == 0,
        }
        for index, page in enumerate(pages)
    ]
    image_candidates.extend(
        {
            "relative_path": image["relative_path"],
            "source": "embedded_image",
            "page_number": None,
            "is_primary": False,
        }
        for image in embedded_images
    )

    treatment_plan = extract_short_field(combined_text, ["治疗", "处理", "治疗方案"]) or ""
    detailed_description = extract_short_field(
        combined_text,
        ["解析", "分析", "说明", "描述"],
        limit=1200,
    )
    if not detailed_description and combined_text:
        detailed_description = combined_text[:1200]

    needs_review = not is_case_like_record or diagnosis == "待人工判读" or not combined_text
    platform_payload = {
        "case_code": f"{case_prefix}-{case_index:04d}",
        "title": title[:255],
        "summary": make_summary(combined_text, keywords, page_range),
        "diagnosis": diagnosis,
        "rhythm_type": keywords[0] if keywords else None,
        "heart_rate": extract_short_field(combined_text, ["心率", "频率"], limit=80),
        "axis_description": extract_short_field(combined_text, ["电轴", "心电轴"], limit=300),
        "pr_description": extract_short_field(combined_text, ["PR", "P-R"], limit=300),
        "qrs_description": extract_short_field(combined_text, ["QRS"], limit=300),
        "st_t_description": extract_short_field(combined_text, ["ST-T", "ST段", "T波"], limit=500),
        "qt_description": extract_short_field(combined_text, ["QT", "Q-T"], limit=300),
        "key_leads": extract_key_leads(combined_text),
        "clinical_significance": extract_short_field(combined_text, ["临床意义", "意义"], limit=700),
        "differential_diagnosis": extract_short_field(combined_text, ["鉴别诊断", "鉴别"], limit=700),
        "treatment_plan": treatment_plan,
        "urgent_actions": extract_short_field(combined_text, ["紧急处理", "急诊处理"], limit=500),
        "follow_up_recommendations": extract_short_field(combined_text, ["随访", "复查"], limit=500),
        "detailed_description": detailed_description,
        "interpretation_steps": default_interpretation_steps(),
        "learning_points": keywords[:5],
        "common_mistakes": [],
        "memory_tips": [],
        "difficulty": difficulty,
        "risk_level": risk_level,
        "is_featured": False,
    }

    return {
        "case_code": platform_payload["case_code"],
        "title": title,
        "source_book": source_book,
        "source_pages": page_numbers,
        "page_range": page_range,
        "chapter_name": chapter_name,
        "case_marker": case_marker,
        "category": keywords[0] if keywords else chapter_name,
        "tags": keywords,
        "diagnosis": diagnosis,
        "diagnosis_hints": keywords,
        "risk_level": risk_level,
        "difficulty": difficulty,
        "needs_manual_review": needs_review,
        "patient_age": patient_info["patient_age"],
        "patient_gender": patient_info["patient_gender"],
        "native_text_available": bool(native_text),
        "ocr_text_available": bool(ocr_text),
        "native_text": native_text[:4000],
        "ocr_text": ocr_text[:4000],
        "combined_text_preview": combined_text[:1200],
        "page_images": [page["page_image_path"] for page in pages],
        "embedded_images": embedded_images,
        "image_candidates": image_candidates,
        "total_images": len(image_candidates),
        "platform_payload": platform_payload,
        "notes": "自动抽取草稿，需要人工校对诊断、风险、治疗方案和图片裁剪；教材章节不会自动当作真实病例诊断。",
    }


def make_summary(text: str, keywords: list[str], page_range: str) -> str:
    if text:
        compact = re.sub(r"\s+", " ", text).strip()
        return compact[:300]
    if keywords:
        return f"来源页码 {page_range}，疑似主题：{'、'.join(keywords)}。"
    return f"来源页码 {page_range}，扫描页暂未识别出文字。"


def extract_key_leads(text: str) -> list[str]:
    leads = []
    for lead in ["I", "II", "III", "aVR", "aVL", "aVF", "V1", "V2", "V3", "V4", "V5", "V6"]:
        if re.search(rf"(?<![A-Za-z0-9]){re.escape(lead)}(?![A-Za-z0-9])", text):
            leads.append(lead)
    return leads


def default_interpretation_steps() -> list[str]:
    return [
        "确认走纸速度、增益和导联完整性",
        "判断心律、心率和电轴",
        "评估 PR、QRS、QT 间期",
        "观察 ST-T 改变和异常波形",
        "结合病史判断风险级别与处理方案",
    ]


def write_outputs(result: dict[str, Any], output_path: Path) -> None:
    ensure_dir(output_path)
    json_path = output_path / "ecg_data_extracted.json"
    import_path = output_path / "admin_import_payloads.json"
    summary_path = output_path / "extraction_summary.txt"

    json_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    import_path.write_text(
        json.dumps(result["admin_import_payloads"], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    summary_path.write_text(build_summary_text(result), encoding="utf-8")

    print(f"Saved dataset: {json_path}")
    print(f"Saved import payloads: {import_path}")
    print(f"Saved summary: {summary_path}")


def build_summary_text(result: dict[str, Any]) -> str:
    source = result["source"]
    summary = result["summary"]
    lines = [
        f"Source: {source['filename']}",
        f"Book title: {source['book_title']}",
        f"Pages processed: {summary['pages_processed']}/{summary['total_pages']}",
        f"Pages with native text: {summary['pages_with_native_text']}",
        f"Pages with OCR text: {summary['pages_with_ocr_text']}",
        f"Scanned/image-only pages: {summary['pages_scanned_or_image_only']}",
        f"Embedded images: {summary['total_embedded_images']}",
        f"Cases grouped: {summary['total_cases_grouped']}",
        f"OCR status: {summary['ocr_status_counts']}",
        "",
        "Cases:",
    ]
    for case in result["cases"][:50]:
        lines.append(
            f"  {case['case_code']}: pages {case['page_range']}, "
            f"diagnosis={case['diagnosis']}, risk={case['risk_level']}, review={case['needs_manual_review']}"
        )
    if len(result["cases"]) > 50:
        lines.append(f"  ... {len(result['cases']) - 50} more")
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract draft ECG cases from PDF books.")
    parser.add_argument("--pdf", help="PDF path. If omitted, --keyword is used.")
    parser.add_argument("--keyword", help="Find first PDF under the default ECG learning folder.")
    parser.add_argument("--output-dir", help="Output directory. Defaults to scripts/extractor/output/<pdf-name>.")
    parser.add_argument("--max-pages", type=int, help="Limit pages for testing.")
    parser.add_argument("--render-dpi", type=int, default=220, help="Page render DPI.")
    parser.add_argument(
        "--ocr",
        choices=["auto", "off", "force"],
        default="auto",
        help="auto OCRs image-only pages if Tesseract is available.",
    )
    parser.add_argument("--ocr-lang", default="chi_sim+eng", help="Tesseract language code.")
    parser.add_argument("--tesseract-cmd", help="Explicit path to tesseract.exe.")
    parser.add_argument("--case-page-span", type=int, default=2, help="Fallback pages per case.")
    parser.add_argument(
        "--grouping",
        choices=["auto", "fixed", "case", "chapter"],
        default="auto",
        help="How to group pages into draft records.",
    )
    parser.add_argument("--case-prefix", default="ECG-BOOK", help="Generated case code prefix.")
    parser.add_argument("--book-title", help="Override source book title.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    pdf_path = find_pdf(keyword=args.keyword, exact_path=args.pdf)
    if not pdf_path:
        print("Error: PDF not found. Provide --pdf or --keyword.", file=sys.stderr)
        return 1

    pdf_file = Path(pdf_path)
    if args.output_dir:
        output_dir = Path(args.output_dir)
    else:
        output_dir = DEFAULT_OUTPUT_ROOT / f"{safe_slug(pdf_file.stem)}_extracted"

    result = extract_pdf(
        pdf_path=str(pdf_file),
        output_base=output_dir,
        render_dpi=args.render_dpi,
        max_pages=args.max_pages,
        ocr_mode=args.ocr,
        ocr_lang=args.ocr_lang,
        tesseract_cmd=args.tesseract_cmd,
        case_page_span=args.case_page_span,
        grouping=args.grouping,
        case_prefix=args.case_prefix,
        book_title=args.book_title,
    )

    summary = result["summary"]
    print("=" * 60)
    print("Extraction complete")
    print(f"  Output: {output_dir}")
    print(f"  Pages: {summary['pages_processed']}/{summary['total_pages']}")
    print(f"  Cases: {summary['total_cases_grouped']}")
    print(f"  Native text pages: {summary['pages_with_native_text']}")
    print(f"  OCR text pages: {summary['pages_with_ocr_text']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
