# Trace Path

Meaningful trace path:

1. `GET /api/accounts/{id}`
2. FastAPI handler receives the request.
3. `accounts.lookup` span wraps the account lookup.
4. Postgres query reads the account row.
5. Handler returns the response.

The span avoids using the raw account ID as an attribute. Account IDs can become high-cardinality identifiers and may need tokenisation or stricter handling in production telemetry.

Business context: this trace lets engineers separate application latency from database latency on the account lookup path. That helps a small bank restore customer-facing account reads quickly without adding sensitive account identifiers to telemetry.
