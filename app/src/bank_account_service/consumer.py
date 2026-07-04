from collections.abc import Mapping
from typing import Any

from bank_account_service.db import get_connection
from bank_account_service.idempotency import mark_event_processed


class InvalidEventError(ValueError):
    pass


def _required_text(event: Mapping[str, Any], key: str) -> str:
    value = event.get(key)
    if not isinstance(value, str) or not value:
        raise InvalidEventError(f"missing_or_invalid_{key}")
    return value


def process_event(event: Mapping[str, Any]) -> bool:
    event_id = _required_text(event, "event_id")
    account_id = _required_text(event, "account_id")
    action = _required_text(event, "action")

    with get_connection() as conn:
        with conn.transaction():
            if not mark_event_processed(conn, event_id):
                return False

            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO audit_events (event_id, account_id, action)
                    VALUES (%s, %s, %s)
                    """,
                    (event_id, account_id, action),
                )

    return True
