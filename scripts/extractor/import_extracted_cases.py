"""Import extracted ECG PDF records into the local ECG Pro API."""

from __future__ import annotations

import argparse
import json
import mimetypes
from pathlib import Path
from typing import Any

import requests


DEFAULT_API_BASE_URL = "http://localhost:8080"
DEFAULT_USERNAME = "niegehedao"
DEFAULT_PASSWORD = "niegehedao123"


def safe_slug(value: str, fallback: str = "item") -> str:
    import hashlib
    import re

    value = value.strip().lower()
    ascii_slug = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    if ascii_slug:
        return ascii_slug[:64]
    digest = hashlib.sha1(value.encode("utf-8")).hexdigest()[:10]
    return f"{fallback}-{digest}"


class ApiClient:
    def __init__(self, base_url: str, username: str, password: str) -> None:
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        response = self.session.post(
            f"{self.base_url}/api/v1/auth/login",
            json={"username": username, "password": password},
            timeout=30,
        )
        response.raise_for_status()
        token = response.json()["access_token"]
        self.session.headers.update({"Authorization": f"Bearer {token}"})

    def get(self, path: str, **params: Any) -> Any:
        response = self.session.get(
            f"{self.base_url}{path}",
            params={key: value for key, value in params.items() if value is not None},
            timeout=60,
        )
        response.raise_for_status()
        return response.json()

    def post(self, path: str, payload: dict[str, Any] | None = None) -> Any:
        response = self.session.post(
            f"{self.base_url}{path}",
            json=payload,
            timeout=60,
        )
        raise_for_status_with_body(response)
        return response.json() if response.content else None

    def put(self, path: str, payload: dict[str, Any]) -> Any:
        response = self.session.put(
            f"{self.base_url}{path}",
            json=payload,
            timeout=60,
        )
        raise_for_status_with_body(response)
        return response.json()

    def upload_image(
        self,
        case_id: str,
        image_path: Path,
        *,
        is_primary: bool,
        sort_order: int,
    ) -> Any:
        content_type = mimetypes.guess_type(image_path.name)[0] or "image/png"
        with image_path.open("rb") as handle:
            response = self.session.post(
                f"{self.base_url}/api/v1/admin/cases/{case_id}/images",
                files={"file": (image_path.name, handle, content_type)},
                data={"is_primary": str(is_primary).lower(), "sort_order": str(sort_order)},
                timeout=120,
            )
        raise_for_status_with_body(response)
        return response.json()


def raise_for_status_with_body(response: requests.Response) -> None:
    try:
        response.raise_for_status()
    except requests.HTTPError as exc:
        body = response.text[:1000]
        raise requests.HTTPError(f"{exc}; response={body}", response=response) from exc


def find_existing_case(client: ApiClient, case_code: str) -> dict[str, Any] | None:
    payload = client.get("/api/v1/admin/cases", keyword=case_code, page=1, page_size=100)
    for item in payload.get("items", []):
        if item.get("case_code") == case_code:
            return item
    return None


def ensure_category(client: ApiClient, name: str, slug: str) -> dict[str, Any]:
    categories = client.get("/api/v1/admin/categories")
    for item in categories:
        if item["slug"] == slug:
            return item

    return client.post(
        "/api/v1/admin/categories",
        {
            "name": name[:128],
            "slug": slug[:128],
            "description": "PDF 自动导入的测试分类。",
            "sort_order": 100,
            "is_visible": True,
            "parent_id": None,
        },
    )


def ensure_tag(client: ApiClient, name: str, slug: str, description: str | None = None) -> dict[str, Any]:
    tags = client.get("/api/v1/admin/tags")
    for item in tags:
        if item["slug"] == slug:
            return item

    return client.post(
        "/api/v1/admin/tags",
        {
            "name": name[:64],
            "slug": slug[:64],
            "description": description,
        },
    )


def collect_json_inputs(paths: list[str]) -> list[Path]:
    result: list[Path] = []
    for raw_path in paths:
        path = Path(raw_path)
        if path.is_dir():
            result.extend(sorted(path.rglob("ecg_data_extracted.json")))
        elif path.is_file():
            result.append(path)
    return result


def build_case_payload(
    case: dict[str, Any],
    category_id: str,
    tag_ids: list[str],
    source_name: str,
) -> dict[str, Any]:
    payload = dict(case["platform_payload"])
    payload["category_id"] = category_id
    payload["tag_ids"] = tag_ids
    payload["summary"] = f"[PDF导入测试] {payload.get('summary') or ''}"[:300]
    payload["detailed_description"] = (
        f"来源：{source_name}；页码：{case.get('page_range')}。\n"
        f"{payload.get('detailed_description') or case.get('combined_text_preview') or ''}"
    )[:1200]
    return truncate_case_payload(payload)


def truncate_case_payload(payload: dict[str, Any]) -> dict[str, Any]:
    limits = {
        "case_code": 32,
        "title": 255,
        "diagnosis": 255,
        "rhythm_type": 128,
        "heart_rate": 64,
    }
    for key, limit in limits.items():
        value = payload.get(key)
        if isinstance(value, str):
            payload[key] = value[:limit]
    return payload


def resolve_image_paths(case: dict[str, Any], json_path: Path, max_images: int) -> list[Path]:
    base_dir = json_path.parent
    paths = []
    for relative_path in case.get("page_images", []):
        path = base_dir / relative_path
        if path.exists():
            paths.append(path)
        if len(paths) >= max_images:
            break
    return paths


def import_file(
    client: ApiClient,
    json_path: Path,
    *,
    publish: bool,
    update_existing: bool,
    max_cases: int | None,
    max_images_per_case: int,
) -> dict[str, int]:
    data = json.loads(json_path.read_text(encoding="utf-8"))
    source = data["source"]
    source_name = source["book_title"] or source["filename"]
    category = ensure_category(
        client,
        name=source_name[:128],
        slug=f"book-{safe_slug(source_name, 'book')}",
    )
    source_tag = ensure_tag(
        client,
        name="PDF导入",
        slug="pdf-import",
        description="由本地 PDF 提取脚本导入的测试内容。",
    )

    stats = {"created": 0, "updated": 0, "skipped": 0, "images": 0, "published": 0}
    for case in data.get("cases", [])[:max_cases]:
        tag_ids = [source_tag["id"]]
        for tag_name in case.get("tags", [])[:4]:
            tag = ensure_tag(client, tag_name, safe_slug(tag_name, "tag"), "PDF OCR 关键词。")
            tag_ids.append(tag["id"])

        payload = build_case_payload(case, category["id"], tag_ids, source_name)
        existing = find_existing_case(client, payload["case_code"])
        if existing and update_existing:
            detail = client.put(f"/api/v1/admin/cases/{existing['id']}", payload)
            stats["updated"] += 1
        elif existing:
            detail = client.get(f"/api/v1/admin/cases/{existing['id']}")
            stats["skipped"] += 1
        else:
            detail = client.post("/api/v1/admin/cases", payload)
            stats["created"] += 1

        if not detail.get("images"):
            for index, image_path in enumerate(resolve_image_paths(case, json_path, max_images_per_case)):
                client.upload_image(
                    detail["id"],
                    image_path,
                    is_primary=index == 0,
                    sort_order=index,
                )
                stats["images"] += 1

        if publish and detail.get("status") != "published":
            client.post(f"/api/v1/admin/cases/{detail['id']}/publish")
            stats["published"] += 1

    return stats


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import extracted ECG PDF cases into ECG Pro.")
    parser.add_argument("inputs", nargs="+", help="ecg_data_extracted.json files or output directories.")
    parser.add_argument("--api-base-url", default=DEFAULT_API_BASE_URL)
    parser.add_argument("--username", default=DEFAULT_USERNAME)
    parser.add_argument("--password", default=DEFAULT_PASSWORD)
    parser.add_argument("--publish", action="store_true", help="Publish imported cases after upload.")
    parser.add_argument("--update-existing", action="store_true", help="Update existing cases by case_code.")
    parser.add_argument("--max-cases", type=int, default=None)
    parser.add_argument("--max-images-per-case", type=int, default=2)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    json_files = collect_json_inputs(args.inputs)
    if not json_files:
        raise SystemExit("No ecg_data_extracted.json files found.")

    client = ApiClient(args.api_base_url, args.username, args.password)
    total = {"created": 0, "updated": 0, "skipped": 0, "images": 0, "published": 0}
    for json_file in json_files:
        print(f"Importing {json_file}")
        stats = import_file(
            client,
            json_file,
            publish=args.publish,
            update_existing=args.update_existing,
            max_cases=args.max_cases,
            max_images_per_case=args.max_images_per_case,
        )
        print(stats)
        for key, value in stats.items():
            total[key] += value

    print(f"Total: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
