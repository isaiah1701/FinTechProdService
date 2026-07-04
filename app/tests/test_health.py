from fastapi.testclient import TestClient

from mal_account_service.main import app


def test_healthz_returns_ok():
    client = TestClient(app)

    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
