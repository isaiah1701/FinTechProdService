# Database Access

## Schema

The local schema has three tables:

- `accounts`: the tiny domain table read by `GET /api/accounts/{id}`
- `audit_events`: side effects written by the messaging consumer
- `processed_events`: idempotency keys used to make duplicate event delivery safe

## Runtime Role

The application connects as `mal_account_app`, not as the database owner.

It can:

- connect to `mal_accounts`
- use the application schema
- `SELECT`, `INSERT`, and `UPDATE` rows in `accounts`
- `SELECT` and `INSERT` audit events
- `SELECT` and `INSERT` processed event IDs
- use the sequence needed by `audit_events`

It cannot:

- create, alter, or drop tables
- create schemas
- manage roles
- act as a superuser
- own the database or tables
- access unrelated schemas

The implementation is in `local/postgres/002_runtime_role.sql`.

## Credentials

Local development uses environment variables and a Kubernetes Secret created at runtime. The repo commits only variable names in `.env.example`, not local or production secret values.

Local bootstrap:

1. Set `MAL_POSTGRES_OWNER_PASSWORD`, `MAL_ACCOUNT_APP_PASSWORD`, and `MAL_GRAFANA_ADMIN_PASSWORD` in the shell or local `.env`.
2. Start dependencies with `make local-up`.
3. Build `DATABASE_URL` in the shell.
4. Create the Kubernetes Secret with `make kind-secret`.

Production mapping:

1. AWS Secrets Manager stores the database credential.
2. External Secrets Operator reads from AWS Secrets Manager.
3. IRSA or EKS Pod Identity grants secret read access without static AWS keys.
4. External Secrets creates a Kubernetes Secret.
5. The pod receives `DATABASE_URL` from the Kubernetes Secret.

Terraform also enables RDS IAM database authentication and scopes `rds-db:connect` to the `mal_account_app` database user. In a production rollout I would choose one operational path per workload: either Secrets Manager-managed credentials, or IAM database authentication with short-lived tokens and client support in the application.

No plaintext database credential is committed.

## PgBouncer

I would not add PgBouncer for this tiny local assessment. In production, I would consider PgBouncer in transaction pooling mode if connection churn or high pod counts put pressure on RDS connection limits. Session pooling would only be used if the application relied on session-level features.
