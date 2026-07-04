# How To Run Locally

This is the minimum path for someone who has just cloned the repository. It runs only Docker, Docker Compose, Postgres, and the application container. It does not use AWS credentials.

## Prerequisites

- Docker
- Docker Compose
- `make`
- `curl`

The local app listens on `localhost:18080`. Local Postgres listens on `localhost:55432` so it does not collide with another Postgres on `5432`.

## Fresh Clone

```bash
git clone <repo-url>
cd FinTechProdService
```

Set local-only passwords in your shell. These are for your machine only and must not be committed:

```bash
export BANK_POSTGRES_OWNER_PASSWORD='owner-local'
export BANK_ACCOUNT_APP_PASSWORD='app-local'
export BANK_POSTGRES_PORT=55432
```

Start only the local database:

```bash
make local-db-up
```

Build and run the app image:

```bash
make docker-build
export DATABASE_URL="postgresql://bank_account_app:${BANK_ACCOUNT_APP_PASSWORD}@host.docker.internal:${BANK_POSTGRES_PORT:-55432}/bank_accounts"
make docker-run
```

Smoke test it:

```bash
curl localhost:18080/healthz
curl localhost:18080/readyz
curl localhost:18080/api/accounts/acc_123
curl localhost:18080/metrics
```

Expected results:

- `/healthz` returns `{"status":"ok"}`
- `/readyz` returns `{"status":"ready"}`
- `/api/accounts/acc_123` returns the seeded example account
- `/metrics` returns Prometheus metrics

## Stop It

Stop the app container:

```bash
make docker-stop
```

Stop local dependencies:

```bash
make local-down
```

## Full Local Stack

The minimum path above starts only Postgres. To also start LocalStack, Prometheus, Grafana, and the OpenTelemetry collector, set the Grafana password and run:

```bash
export BANK_GRAFANA_ADMIN_PASSWORD='grafana-local'
make local-up
```

Grafana then listens on `localhost:3000` and Prometheus on `localhost:9090`.

## Optional kind Run

For Kubernetes validation on kind:

```bash
kind create cluster --name bank-platform
make docker-build
kind load docker-image bank-account-service:local --name bank-platform
export KIND_HOST_GATEWAY="$(docker inspect bank-platform-control-plane --format '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}')"
export DATABASE_URL="postgresql://bank_account_app:${BANK_ACCOUNT_APP_PASSWORD}@${KIND_HOST_GATEWAY}:${BANK_POSTGRES_PORT:-55432}/bank_accounts"
make kind-secret
make kind-deploy
kubectl rollout status deployment/bank-account-service --timeout=120s
kubectl port-forward svc/bank-account-service 18080:8080
```

Then run the same `curl` smoke tests from above.

## Troubleshooting

If `make local-db-up` fails because port `55432` is busy, choose another local port:

```bash
export BANK_POSTGRES_PORT=55433
make local-db-up
```

If `/readyz` returns `database_unreachable`, check that the database is healthy:

```bash
docker compose -f local/docker-compose.yml ps postgres
```

If you changed the local database passwords after Postgres had already created its volume, stop the stack and remove the old local Postgres volume before starting again:

```bash
make local-down
docker volume rm local_postgres-data
make local-db-up
```
