from fastapi.testclient import TestClient


def _create_published_case(
    client: TestClient,
    admin_headers: dict[str, str],
) -> str:
    category = client.post(
        "/api/v1/admin/categories",
        headers=admin_headers,
        json={
            "name": "影像案例",
            "slug": "image-cases",
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
            "case_code": "ECG-MEDIA-001",
            "title": "房扑案例学习",
            "summary": "用于图片和学习记录测试",
            "diagnosis": "心房扑动",
            "difficulty": "intermediate",
            "risk_level": "medium",
            "category_id": category_id,
            "tag_ids": [],
            "is_featured": False,
            "key_leads": ["II"],
            "interpretation_steps": ["看 F 波"],
            "learning_points": ["识别锯齿样波形"],
            "common_mistakes": ["误判为窦性心动过速"],
            "memory_tips": ["优先观察下壁导联"],
        },
    )
    case_id = created_case.json()["id"]
    publish_response = client.post(
        f"/api/v1/admin/cases/{case_id}/publish",
        headers=admin_headers,
    )
    assert publish_response.status_code == 200
    return case_id


def test_admin_can_manage_case_images_and_public_can_fetch_them(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    case_id = _create_published_case(client, admin_headers)

    first_upload_response = client.post(
        f"/api/v1/admin/cases/{case_id}/images",
        headers=admin_headers,
        files={
            "file": ("ecg-primary.png", b"fake-primary-image", "image/png"),
        },
        data={
            "is_primary": "true",
            "sort_order": "1",
        },
    )
    assert first_upload_response.status_code == 201
    first_image = first_upload_response.json()

    second_upload_response = client.post(
        f"/api/v1/admin/cases/{case_id}/images",
        headers=admin_headers,
        files={
            "file": ("ecg-secondary.png", b"fake-secondary-image", "image/png"),
        },
        data={
            "is_primary": "false",
            "sort_order": "2",
        },
    )
    assert second_upload_response.status_code == 201
    second_image = second_upload_response.json()

    update_primary_response = client.patch(
        f"/api/v1/admin/case-images/{second_image['id']}",
        headers=admin_headers,
        json={"is_primary": True},
    )
    assert update_primary_response.status_code == 200
    assert update_primary_response.json()["is_primary"] is True

    reorder_response = client.put(
        f"/api/v1/admin/cases/{case_id}/images/order",
        headers=admin_headers,
        json={
            "items": [
                {"image_id": second_image["id"], "sort_order": 1},
                {"image_id": first_image["id"], "sort_order": 2},
            ]
        },
    )
    assert reorder_response.status_code == 200
    assert reorder_response.json()[0]["id"] == second_image["id"]

    detail_response = client.get(f"/api/v1/public/cases/{case_id}")
    assert detail_response.status_code == 200
    assert len(detail_response.json()["images"]) == 2
    assert detail_response.json()["images"][0]["id"] == second_image["id"]
    assert detail_response.json()["images"][0]["is_primary"] is True
    assert detail_response.json()["images"][1]["id"] == first_image["id"]

    image_file_response = client.get(
        f"/api/v1/public/images/{second_image['id']}/file",
    )
    assert image_file_response.status_code == 200
    assert image_file_response.content == b"fake-secondary-image"

    delete_response = client.delete(
        f"/api/v1/admin/case-images/{second_image['id']}",
        headers=admin_headers,
    )
    assert delete_response.status_code == 204

    detail_after_delete = client.get(f"/api/v1/public/cases/{case_id}")
    assert detail_after_delete.status_code == 200
    assert len(detail_after_delete.json()["images"]) == 1
    assert detail_after_delete.json()["images"][0]["id"] == first_image["id"]
    assert detail_after_delete.json()["images"][0]["is_primary"] is True


def test_learning_progress_favorites_and_wrong_questions_are_recorded(
    client: TestClient,
    admin_headers: dict[str, str],
    student_headers: dict[str, str],
) -> None:
    case_id = _create_published_case(client, admin_headers)

    create_question_response = client.post(
        f"/api/v1/admin/cases/{case_id}/questions",
        headers=admin_headers,
        json={
            "stem": "房扑最常见的心电图特征是？",
            "explanation": "需要识别规则 F 波。",
            "question_type": "single_choice",
            "difficulty": "intermediate",
            "sort_order": 1,
            "is_active": True,
            "options": [
                {"label": "A", "content": "锯齿样 F 波", "is_correct": True, "sort_order": 1},
                {"label": "B", "content": "完全不规则 RR", "is_correct": False, "sort_order": 2},
            ],
        },
    )
    question = create_question_response.json()
    correct_option_id = next(
        option["id"] for option in question["options"] if option["is_correct"]
    )
    wrong_option_id = next(
        option["id"] for option in question["options"] if not option["is_correct"]
    )

    view_response = client.post(
        f"/api/v1/user/learning/cases/{case_id}/view",
        headers=student_headers,
    )
    assert view_response.status_code == 200
    assert view_response.json()["status"] == "in_progress"
    assert view_response.json()["completion_rate"] == 10

    favorite_response = client.post(
        f"/api/v1/user/favorites/{case_id}",
        headers=student_headers,
    )
    assert favorite_response.status_code == 201

    list_favorites_response = client.get(
        "/api/v1/user/favorites",
        headers=student_headers,
    )
    assert list_favorites_response.status_code == 200
    assert len(list_favorites_response.json()) == 1

    wrong_submit_response = client.post(
        "/api/v1/user/quiz/submit",
        headers=student_headers,
        json={
            "case_id": case_id,
            "mode": "case_quiz",
            "answers": [
                {
                    "question_id": question["id"],
                    "selected_option_ids": [wrong_option_id],
                }
            ],
        },
    )
    assert wrong_submit_response.status_code == 200
    assert wrong_submit_response.json()["score"] == 0
    assert wrong_submit_response.json()["correct_count"] == 0
    first_attempt_id = wrong_submit_response.json()["attempt_id"]

    wrong_questions_response = client.get(
        "/api/v1/user/wrong-questions",
        headers=student_headers,
    )
    assert wrong_questions_response.status_code == 200
    assert len(wrong_questions_response.json()) == 1
    assert wrong_questions_response.json()[0]["question_id"] == question["id"]

    correct_submit_response = client.post(
        "/api/v1/user/quiz/submit",
        headers=student_headers,
        json={
            "case_id": case_id,
            "mode": "case_quiz",
            "answers": [
                {
                    "question_id": question["id"],
                    "selected_option_ids": [correct_option_id],
                }
            ],
        },
    )
    assert correct_submit_response.status_code == 200
    assert correct_submit_response.json()["score"] == 100
    second_attempt_id = correct_submit_response.json()["attempt_id"]

    attempts_response = client.get(
        "/api/v1/user/quiz/attempts",
        headers=student_headers,
        params={"case_id": case_id, "page": 1, "page_size": 10},
    )
    assert attempts_response.status_code == 200
    assert attempts_response.json()["total"] == 2
    assert len(attempts_response.json()["items"]) == 2
    assert attempts_response.json()["items"][0]["attempt_id"] == second_attempt_id

    attempt_detail_response = client.get(
        f"/api/v1/user/quiz/attempts/{first_attempt_id}",
        headers=student_headers,
    )
    assert attempt_detail_response.status_code == 200
    assert attempt_detail_response.json()["attempt_id"] == first_attempt_id
    assert attempt_detail_response.json()["items"][0]["is_correct"] is False
    assert attempt_detail_response.json()["items"][0]["question_id"] == question["id"]

    progress_response = client.get(
        "/api/v1/user/learning/progress",
        headers=student_headers,
    )
    assert progress_response.status_code == 200
    assert len(progress_response.json()) == 1
    assert progress_response.json()[0]["status"] == "completed"
    assert progress_response.json()[0]["best_score"] == 100

    remove_favorite_response = client.delete(
        f"/api/v1/user/favorites/{case_id}",
        headers=student_headers,
    )
    assert remove_favorite_response.status_code == 204

    list_favorites_after_remove = client.get(
        "/api/v1/user/favorites",
        headers=student_headers,
    )
    assert list_favorites_after_remove.status_code == 200
    assert list_favorites_after_remove.json() == []
