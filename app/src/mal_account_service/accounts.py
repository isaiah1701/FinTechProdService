from fastapi import APIRouter, HTTPException

from mal_account_service import db
from mal_account_service.tracing import get_tracer

router = APIRouter()


@router.get("/api/accounts/{account_id}")
def get_account(account_id: str) -> dict[str, object]:
    tracer = get_tracer()
    with tracer.start_as_current_span("accounts.lookup") as span:
        span.set_attribute("account.lookup", "by_id")
        account = db.fetch_account(account_id)

    if account is None:
        raise HTTPException(status_code=404, detail="account_not_found")

    return account
