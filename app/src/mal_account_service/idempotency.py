from typing import Protocol


class Cursor(Protocol):
    def execute(self, query: str, params: tuple[object, ...] | None = None) -> object:
        ...

    def fetchone(self) -> object | None:
        ...


class Connection(Protocol):
    def cursor(self) -> object:
        ...


def mark_event_processed(conn: Connection, event_id: str) -> bool:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO processed_events (event_id)
            VALUES (%s)
            ON CONFLICT (event_id) DO NOTHING
            RETURNING event_id
            """,
            (event_id,),
        )
        return cur.fetchone() is not None
