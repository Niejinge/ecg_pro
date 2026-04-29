from fastapi.testclient import TestClient


def test_admin_can_login_and_fetch_profile(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    me_response = client.get("/api/v1/auth/me", headers=admin_headers)

    assert me_response.status_code == 200
    payload = me_response.json()
    assert payload["username"] == "niegehedao"
    assert payload["is_superuser"] is True
    assert "admin" in payload["role_codes"]


def test_student_cannot_access_admin_dashboard(
    client: TestClient,
    student_headers: dict[str, str],
) -> None:
    response = client.get(
        "/api/v1/admin/dashboard/summary",
        headers=student_headers,
    )

    assert response.status_code == 403
