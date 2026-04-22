from fastapi.testclient import TestClient


def _create_case_for_quiz(
    client: TestClient,
    admin_headers: dict[str, str],
) -> str:
    category = client.post(
        "/api/v1/admin/categories",
        headers=admin_headers,
        json={
            "name": "基础节律",
            "slug": "basic-rhythm",
            "description": None,
            "sort_order": 0,
            "is_visible": True,
            "parent_id": None,
        },
    )
    category_id = category.json()["id"]

    created_case = client.post(
        "/api/v1/admin/cases",
        headers=admin_headers,
        json={
            "case_code": "ECG-QUIZ-001",
            "title": "窦性心律测验",
            "summary": "基础判断题",
            "diagnosis": "窦性心律",
            "difficulty": "beginner",
            "risk_level": "low",
            "category_id": category_id,
            "tag_ids": [],
            "is_featured": False,
            "key_leads": [],
            "interpretation_steps": [],
            "learning_points": [],
            "common_mistakes": [],
            "memory_tips": [],
        },
    )
    case_id = created_case.json()["id"]
    client.post(f"/api/v1/admin/cases/{case_id}/publish", headers=admin_headers)
    return case_id


def test_admin_can_manage_case_questions_and_public_quiz_hides_answers(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    case_id = _create_case_for_quiz(client, admin_headers)

    create_question_response = client.post(
        f"/api/v1/admin/cases/{case_id}/questions",
        headers=admin_headers,
        json={
            "stem": "以下哪项最符合窦性心律？",
            "explanation": "应识别规则节律和正常 P-QRS 关系。",
            "question_type": "single_choice",
            "difficulty": "beginner",
            "sort_order": 1,
            "is_active": True,
            "options": [
                {"label": "A", "content": "P 波规律，QRS 窄，节律整齐", "is_correct": True, "sort_order": 1},
                {"label": "B", "content": "完全不规则", "is_correct": False, "sort_order": 2},
            ],
        },
    )
    assert create_question_response.status_code == 201
    question_payload = create_question_response.json()
    question_id = question_payload["id"]
    assert question_payload["options"][0]["is_correct"] is True

    list_admin_questions = client.get(
        f"/api/v1/admin/cases/{case_id}/questions",
        headers=admin_headers,
    )
    assert list_admin_questions.status_code == 200
    assert len(list_admin_questions.json()) == 1

    public_quiz_response = client.get(f"/api/v1/public/cases/{case_id}/quiz")
    assert public_quiz_response.status_code == 200
    public_question = public_quiz_response.json()[0]
    assert "is_correct" not in public_question["options"][0]

    update_question_response = client.put(
        f"/api/v1/admin/questions/{question_id}",
        headers=admin_headers,
        json={
            "stem": "窦性心律的正确表现是？",
            "explanation": "看 P 波与 QRS 的对应关系。",
            "question_type": "single_choice",
            "difficulty": "beginner",
            "sort_order": 1,
            "is_active": True,
            "options": [
                {"label": "A", "content": "规则 P-QRS 关系", "is_correct": True, "sort_order": 1},
                {"label": "B", "content": "完全不规则 RR 间期", "is_correct": False, "sort_order": 2},
            ],
        },
    )
    assert update_question_response.status_code == 200
    assert update_question_response.json()["stem"] == "窦性心律的正确表现是？"

    delete_question_response = client.delete(
        f"/api/v1/admin/questions/{question_id}",
        headers=admin_headers,
    )
    assert delete_question_response.status_code == 204

    list_after_delete = client.get(
        f"/api/v1/admin/cases/{case_id}/questions",
        headers=admin_headers,
    )
    assert list_after_delete.status_code == 200
    assert list_after_delete.json() == []


def test_single_choice_question_requires_exactly_one_correct_option(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    case_id = _create_case_for_quiz(client, admin_headers)

    invalid_question_response = client.post(
        f"/api/v1/admin/cases/{case_id}/questions",
        headers=admin_headers,
        json={
            "stem": "无效题目",
            "explanation": None,
            "question_type": "single_choice",
            "difficulty": "beginner",
            "sort_order": 1,
            "is_active": True,
            "options": [
                {"label": "A", "content": "选项一", "is_correct": True, "sort_order": 1},
                {"label": "B", "content": "选项二", "is_correct": True, "sort_order": 2},
            ],
        },
    )

    assert invalid_question_response.status_code == 422
