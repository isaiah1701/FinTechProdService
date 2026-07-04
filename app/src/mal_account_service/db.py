from typing import Any

import psycopg
from psycopg.rows import dict_row

from mal_account_service.config import get_settings


def get_connection(database_url: str | None = None) -> psycopg.Connection:
    target_database_url = database_url or get_settings().database_url
    if not target_database_url:
        raise RuntimeError("DATABASE_URL is required")

    return psycopg.connect(
        target_database_url,
        row_factory=dict_row,
        connect_timeout=2,
    )


def ping_database() -> bool:
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return True
    except Exception:
        return False


def fetch_account(account_id: str) -> dict[str, Any] | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, owner_name, balance_pence, currency, created_at
                FROM accounts
                WHERE id = %s
                """,
                (account_id,),
            )
            row = cur.fetchone()
            return dict(row) if row else None
