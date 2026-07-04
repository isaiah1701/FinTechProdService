from fastapi.testclient import TestClient

from mal_account_service import readiness
from mal_account_service.main import app


def test_readyz_returns_ok_when_database_is_reachable(monkeypatch):
    readiness.reset_draining_for_tests()
    monkeypatch.setattr(readiness, "ping_database", lambda: True)
    client = TestClient(app)

    response = client.get("/readyz")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_readyz_fails_when_draining(monkeypatch):
    readiness.reset_draining_for_tests()
    monkeypatch.setattr(readiness, "ping_database", lambda: True)
    readiness.mark_draining()
    client = TestClient(app)

    response = client.get("/readyz")

    assert response.status_code == 503
    assert response.json()["detail"] == "draining"
    readiness.reset_draining_for_tests()


def test_readyz_fails_when_database_is_unreachable(monkeypatch):
    readiness.reset_draining_for_tests()
    monkeypatch.setattr(readiness, "ping_database", lambda: False)
    client = TestClient(app)

    response = client.get("/readyz")

    assert response.status_code == 503
    assert response.json()["detail"] == "database_unreachable"
