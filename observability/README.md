# Observability

The service exposes Prometheus metrics at `/metrics`:

- `mal_account_service_http_requests_total`
- `mal_account_service_http_request_errors_total`
- `mal_account_service_http_request_duration_seconds`

The SLO in `DECISIONS.md` focuses on successful account lookups: non-5xx and under 300ms.

Business context:

- request rate shows whether account lookup demand is changing during onboarding, releases, or incidents
- error rate shows customer-impacting failures, not just infrastructure health
- p95 latency shows whether account reads are fast enough for banking workflows before average latency hides tail pain
- the page alert intentionally fires on SLO burn for account lookup because a young bank needs to protect trust while still shipping quickly

Local Prometheus config lives in `local/prometheus/prometheus.yml`. The dashboard files are intentionally basic; the alert is the more important assessment artifact.
