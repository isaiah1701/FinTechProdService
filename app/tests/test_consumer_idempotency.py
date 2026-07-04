from mal_account_service import consumer


class NoopContext:
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


class FakeCursor:
    def __init__(self, conn):
        self.conn = conn
        self.result = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def execute(self, query, params=None):
        normalized = " ".join(query.split()).lower()
        if normalized.startswith("insert into processed_events"):
            event_id = params[0]
            if event_id in self.conn.processed_events:
                self.result = None
            else:
                self.conn.processed_events.add(event_id)
                self.result = {"event_id": event_id}
            return

        if normalized.startswith("insert into audit_events"):
            self.conn.audit_events.append(
                {
                    "event_id": params[0],
                    "account_id": params[1],
                    "action": params[2],
                }
            )
            return

        raise AssertionError(f"unexpected query: {query}")

    def fetchone(self):
        return self.result


class FakeConnection:
    def __init__(self):
        self.processed_events = set()
        self.audit_events = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def transaction(self):
        return NoopContext()

    def cursor(self):
        return FakeCursor(self)


def test_duplicate_events_create_one_audit_record(monkeypatch):
    fake_conn = FakeConnection()
    monkeypatch.setattr(consumer, "get_connection", lambda: fake_conn)
    event = {
        "event_id": "evt_123",
        "account_id": "acc_123",
        "action": "ACCOUNT_VIEWED",
    }

    first = consumer.process_event(event)
    second = consumer.process_event(event)

    assert first is True
    assert second is False
    assert fake_conn.audit_events == [
        {
            "event_id": "evt_123",
            "account_id": "acc_123",
            "action": "ACCOUNT_VIEWED",
        }
    ]
