from fastapi.testclient import TestClient


def test_admin_can_manage_taxonomy_and_cases(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    category_response = client.post(
        "/api/v1/admin/categories",
        headers=admin_headers,
        json={
            "name": "快速性心律失常",
            "slug": "tachy-arrhythmia",
            "description": "心动过速相关案例",
            "sort_order": 1,
            "is_visible": True,
            "parent_id": None,
        },
    )
    assert category_response.status_code == 201
    category_id = category_response.json()["id"]

    tag_response = client.post(
        "/api/v1/admin/tags",
        headers=admin_headers,
        json={
            "name": "高危",
            "slug": "high-risk",
            "description": "需要重点关注的高风险案例",
        },
    )
    assert tag_response.status_code == 201
    tag_id = tag_response.json()["id"]

    create_case_response = client.post(
        "/api/v1/admin/cases",
        headers=admin_headers,
        json={
            "case_code": "ECG-001",
            "title": "室上性心动过速识别",
            "summary": "典型窄 QRS 心动过速案例",
            "diagnosis": "室上性心动过速",
            "rhythm_type": "规则快速心律",
            "heart_rate": "180 bpm",
            "axis_description": "电轴正常",
            "pr_description": "难以辨认",
            "qrs_description": "QRS 窄",
            "st_t_description": "继发性 ST-T 改变",
            "qt_description": "QT 评估受限",
            "key_leads": ["II", "V1"],
            "clinical_significance": "需快速识别并处理",
            "differential_diagnosis": "房扑 2:1 下传",
            "treatment_plan": "迷走神经刺激或腺苷",
            "urgent_actions": "监测血流动力学",
            "follow_up_recommendations": "必要时进一步电生理评估",
            "detailed_description": "这是一个用于教学的典型 SVT 案例。",
            "interpretation_steps": ["看心率", "看节律", "看 QRS"],
            "learning_points": ["识别窄 QRS 心动过速", "区分规则与不规则"],
            "common_mistakes": ["误判为窦性心动过速"],
            "memory_tips": ["先看 QRS 宽窄"],
            "difficulty": "intermediate",
            "risk_level": "high",
            "category_id": category_id,
            "tag_ids": [tag_id],
            "is_featured": True,
        },
    )
    assert create_case_response.status_code == 201
    case_payload = create_case_response.json()
    case_id = case_payload["id"]
    assert case_payload["status"] == "draft"
    assert case_payload["category"]["id"] == category_id
    assert case_payload["tags"][0]["id"] == tag_id

    list_admin_cases_response = client.get(
        "/api/v1/admin/cases",
        headers=admin_headers,
    )
    assert list_admin_cases_response.status_code == 200
    assert len(list_admin_cases_response.json()) == 1

    public_detail_before_publish = client.get(f"/api/v1/public/cases/{case_id}")
    assert public_detail_before_publish.status_code == 404

    publish_response = client.post(
        f"/api/v1/admin/cases/{case_id}/publish",
        headers=admin_headers,
    )
    assert publish_response.status_code == 200
    assert publish_response.json()["status"] == "published"

    public_cases_response = client.get("/api/v1/public/cases")
    assert public_cases_response.status_code == 200
    assert len(public_cases_response.json()) == 1
    assert public_cases_response.json()[0]["case_code"] == "ECG-001"

    public_detail_after_publish = client.get(f"/api/v1/public/cases/{case_id}")
    assert public_detail_after_publish.status_code == 200
    detail_payload = public_detail_after_publish.json()
    assert detail_payload["category"]["slug"] == "tachy-arrhythmia"
    assert detail_payload["tags"][0]["slug"] == "high-risk"

    public_categories_response = client.get("/api/v1/public/categories")
    assert public_categories_response.status_code == 200
    assert public_categories_response.json()[0]["slug"] == "tachy-arrhythmia"

    public_tags_response = client.get("/api/v1/public/tags")
    assert public_tags_response.status_code == 200
    assert public_tags_response.json()[0]["slug"] == "high-risk"

    offline_response = client.post(
        f"/api/v1/admin/cases/{case_id}/offline",
        headers=admin_headers,
    )
    assert offline_response.status_code == 200
    assert offline_response.json()["status"] == "offline"

    public_cases_after_offline = client.get("/api/v1/public/cases")
    assert public_cases_after_offline.status_code == 200
    assert public_cases_after_offline.json() == []


def test_category_slug_must_be_unique(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    payload = {
        "name": "基础节律",
        "slug": "rhythm-basics",
        "description": None,
        "sort_order": 0,
        "is_visible": True,
        "parent_id": None,
    }

    first = client.post("/api/v1/admin/categories", headers=admin_headers, json=payload)
    second = client.post("/api/v1/admin/categories", headers=admin_headers, json=payload)

    assert first.status_code == 201
    assert second.status_code == 409
