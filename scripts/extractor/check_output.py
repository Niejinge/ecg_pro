"""Print a compact summary for ECG extractor JSON outputs."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "output"

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def get_summary_value(summary: dict[str, Any], key: str, default: Any = 0) -> Any:
    return summary.get(key, default)


def iter_json_files(output_dir: Path) -> list[Path]:
    return sorted(output_dir.rglob("ecg_data_extracted.json"))


def print_file_summary(json_file: Path) -> None:
    data = json.loads(json_file.read_text(encoding="utf-8"))
    summary = data.get("summary", {})
    source = data.get("source", {})
    cases = data.get("cases", [])

    print(f"Reading: {json_file}")
    print(f"  Source: {source.get('filename', '-')}")
    print(
        "  Pages: "
        f"{get_summary_value(summary, 'pages_processed')}/"
        f"{get_summary_value(summary, 'total_pages')}"
    )
    print(f"  Cases: {get_summary_value(summary, 'total_cases_grouped')}")
    print(f"  Native text pages: {get_summary_value(summary, 'pages_with_native_text')}")
    print(f"  OCR text pages: {get_summary_value(summary, 'pages_with_ocr_text')}")
    print(f"  Pages with case markers: {get_summary_value(summary, 'pages_with_case_numbers')}")
    print()

    for case in cases[:5]:
        print(f"  Case: {case.get('case_code')}")
        print(f"    Title: {case.get('title')}")
        print(f"    Diagnosis: {case.get('diagnosis')}")
        print(f"    Risk: {case.get('risk_level')}")
        print(f"    Tags: {case.get('tags')}")
        print(f"    Pages: {case.get('source_pages')}")
        print(f"    Images: {case.get('total_images')}")
        preview = case.get("combined_text_preview") or case.get("ocr_text") or case.get("native_text") or ""
        print(f"    Text preview: {preview[:150]}")
        print()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check ECG extractor output.")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR), help="Extractor output root.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output_dir)
    files = iter_json_files(output_dir)
    if not files:
        print(f"No ecg_data_extracted.json files found under {output_dir}")
        return 1

    for json_file in files:
        print_file_summary(json_file)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
