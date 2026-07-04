from fastapi.testclient import TestClient

from mal_account_service import db
from mal_account_service.main import app


def test_get_account_returns_account(monkeypatch):
    monkeypatch.setattr(
        db,
        "fetch_account",
        lambda account_id: {
            "id": account_id,
            "owner_name": "Example Customer",
            "balance_pence": 125000,
            "currency": "GBP",
            "created_at": "2026-01-01T00:00:00Z",
        },
    )
    client = TestClient(app)

    response = client.get("/api/accounts/acc_123")

    assert response.status_code == 200
    assert response.json()["id"] == "acc_123"
    assert response.json()["balance_pence"] == 125000


def test_get_account_returns_404(monkeypatch):
    monkeypatch.setattr(db, "fetch_account", lambda account_id: None)
    client = TestClient(app)

    response = client.get("/api/accounts/missing")

    assert response.status_code == 404
    assert response.json()["detail"] == "account_not_found"
