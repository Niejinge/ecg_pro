"""Inspect one extracted case for quick manual review."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


DEFAULT_JSON = Path(__file__).resolve().parent / "output" / "ecg_book2_extracted" / "ecg_data_extracted.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Inspect an extracted ECG case.")
    parser.add_argument("--json", default=str(DEFAULT_JSON), help="Path to ecg_data_extracted.json.")
    parser.add_argument("--case-code", default=None, help="Case code. Defaults to the 5th case.")
    parser.add_argument("--index", type=int, default=5, help="1-based case index when --case-code is omitted.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    data = json.loads(Path(args.json).read_text(encoding="utf-8"))
    cases = data.get("cases", [])
    if not cases:
        print("No cases found.")
        return 1

    if args.case_code:
        case = next((item for item in cases if item.get("case_code") == args.case_code), None)
    else:
        case = cases[args.index - 1] if 0 < args.index <= len(cases) else None

    if not case:
        print("Case not found.")
        return 1

    for key in [
        "case_code",
        "title",
        "source_pages",
        "chapter_name",
        "category",
        "tags",
        "total_images",
        "page_images",
        "diagnosis",
        "risk_level",
        "needs_manual_review",
        "notes",
    ]:
        print(f"  {key}: {case.get(key)}")

    print("  Image candidates:")
    for image in case.get("image_candidates", [])[:10]:
        print(f"    {image.get('source')}: {image.get('relative_path')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
