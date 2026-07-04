# Decisions and Trade-offs

Context: this service is framed as an early-stage bank. The platform should let a small team move quickly, but account lookup reliability is customer trust, not just infrastructure hygiene.

## Biggest Decisions

### 1. Observability-first health, readiness, and graceful draining

The application is deliberately small, so the important platform question is: can we tell what is healthy, what is unhealthy, and why?

I made health, readiness, metrics, tracing, and alerting first-class rather than add-ons. `/healthz` tells us the process is alive. `/readyz` tells Kubernetes whether the pod can safely receive traffic, including whether Postgres is reachable and whether the pod is draining after SIGTERM. RED metrics show request rate, errors, and duration. Traces show the path through `GET /api/accounts/{id}` into the database query.

Why I would defend it: during an early production rollout, this gives the team a simple operating baseline. Non-technically: it is the dashboard and warning lights before driving the car on the motorway. It makes root-cause analysis and recovery faster because the team can see whether the process, database dependency, traffic path, or request latency is the problem.

Trade-off: this adds a little implementation and configuration effort upfront, but it avoids launching a greenfield service that can fail silently or require guesswork during incidents.

### 2. SQS-style queue with idempotent consumer

I chose SQS-style messaging because this is a greenfield service with one simple asynchronous side effect. At this stage the service needs retry, visibility timeout, DLQ behaviour, and horizontal consumer scaling; it does not yet need global ordering, long-term replay, stream joins, or event-sourcing semantics.

Why I would defend it: SQS keeps the platform boring while the bank is still early. Account lookup stays fast, audit side effects can be retried safely, and duplicate delivery is handled with a `processed_events` table inside the database transaction.

Trade-off: SQS is intentionally limited. If the bank later needs replayable event history, fan-out to many independent consumers, ordered streams, analytics pipelines, or stronger event-platform governance, I would move to Kafka or a managed Kafka-compatible service. That would buy richer messaging semantics, but it also introduces broker operations, partitioning decisions, schema governance, consumer lag management, capacity planning, and more infrastructure to run safely.

### 3. No PgBouncer locally; transaction pooling in production if needed

I did not add PgBouncer to the local assessment because it would add moving parts without improving the review signal. In production, I would consider PgBouncer in transaction pooling mode if pod count or connection churn put pressure on RDS connection limits.

Why I would defend it: the local stack stays understandable, while the production decision has a clear scaling trigger. Transaction pooling fits this service because account lookup requests are short-lived and do not rely on session-level database state. In plain English, it lets many app requests share fewer real database connections, which protects RDS from being overwhelmed as the number of pods grows.

Trade-off: transaction pooling can break workloads that rely on session features such as temporary tables, session variables, `LISTEN/NOTIFY`, or connection-pinned prepared statements. I would avoid those patterns in the app before adopting transaction pooling.

## SLO and Alerting

Service SLO:

- SLI: percentage of successful account lookup requests.
- Success definition: `GET /api/accounts/{id}` returns non-5xx within 300ms.
- Target: 99.9% over 30 days.
- User impact: customers and internal banking workflows need account reads to complete reliably and quickly.

Why this matters:

This endpoint represents a key user transaction. If account reads are failing or slow, customers and internal banking workflows lose access to core account information. I would not start by chasing more nines because this is an early-stage platform; without production traffic, mature observability, and incident history, a more aggressive target would be guesswork rather than engineering.

Paging design:

I would use a multi-window burn-rate alert on account lookup error-budget consumption. This catches slow degradation that may never trip one static threshold, such as a database gradually getting slower or a small but sustained 5xx rate.

The one alert I would keep:

Page when account lookup SLO burn is high across both windows:

- fast burn: bad account lookups over 5 minutes
- sustained burn: the same symptom remains elevated over 1 hour
- traffic guard: only page when request volume is non-trivial

This is better than paging only on CPU or one latency threshold because it is tied directly to user impact. It also gives the team a repeatable alerting pattern that can be reused across the platform as more services mature.

## Least Privilege and Blast Radius

The application connects to Postgres as `bank_account_app`, not as an owner or migration role.

The database role can:

- connect to the application database
- use the application schema
- `SELECT`, `INSERT`, and `UPDATE` required account rows
- `SELECT` and `INSERT` audit events
- `SELECT` and `INSERT` processed event IDs
- use the sequence needed for audit event inserts

The database role cannot:

- create, alter, or drop tables
- manage roles
- act as database owner
- act as superuser
- access unrelated schemas
- perform unrestricted DDL

Workload identity model:

In production, the pod uses IRSA or EKS Pod Identity. It can read only the specific Secrets Manager secret needed by this workload, consume only the intended SQS queue, and connect as the intended database user where RDS IAM auth is used.

If a pod is compromised through RCE, the attacker is limited to the permissions of the workload and the runtime database role. They can reach:

- the application database through the limited `bank_account_app` grants
- the workload-specific database secret exposed to this pod
- the SQS actions explicitly granted to the workload
- network destinations allowed by NetworkPolicy and AWS security groups

This reduces blast radius from broad platform or database compromise to the narrow permissions needed by the account service. It does not magically protect every individual row; row-level isolation would require additional controls such as RLS, tenant scoping, or application-level authorization.

The design deliberately denies:

- static AWS keys in the pod or repository
- broad AWS permissions
- database ownership
- DDL permissions
- unrelated Secrets Manager access
- privileged container execution, root user, privilege escalation, and Linux capabilities

## Recovery

Postgres:

- Target RPO: approximately 5 minutes.
- Target RTO: under 1 hour.

Reasoning: account reads are important to trust and operations, but this demo service is not the payment ledger. RDS point-in-time recovery gives a practical recovery point without building a custom backup system. Under 1 hour is a realistic target for restoring a managed instance, validating data, updating configuration, and confirming application health.

How I would prove restore works before needing it:

1. restore into a new isolated RDS instance
2. run schema and row-count checks
3. point a test deployment at the restored database
4. verify `/readyz`
5. verify a known-safe account lookup
6. document the result and run the drill regularly
7. never test restore by overwriting production

Messaging:

During an outage, unprocessed messages remain in SQS until retention expires. In-flight messages become visible again after the visibility timeout if they are not acknowledged. After recovery, consumers may receive duplicates, so the `processed_events` idempotency table is required.

Poison messages move to the DLQ after `maxReceiveCount = 3`. Operators inspect, fix, replay, or discard them depending on failure type.

## What I Cut

For time, I deprioritised items that improve developer experience or production maturity but are not required to prove the core service behaviour:

- full AWS deployment
- full LocalStack end-to-end validation
- polished Grafana dashboards
- ArgoCD
- service mesh
- Backstage
- advanced policy-as-code
- complete migration framework
- load testing

These are valuable in a real rollout, but under the assessment time limit I prioritised the controls closest to reliability and regulated-bank operation: dependency-aware readiness, graceful rollout, least-privilege database access, idempotent messaging, recovery thinking, and SLO-based alerting.

What I would implement first in a real rollout:

1. real migration tooling with Alembic or Flyway
2. restore drill automation
3. production External Secrets wiring
4. image signing and SBOM generation
5. live burn-rate alerts connected to the actual monitoring stack

Terraform is authored and validated locally but not applied. The local stack demonstrates workload behaviour; the AWS production mapping is documented and expressed in Terraform.

## CI/CD Trade-off

I chose immutable image tags and Helm release revisions as the deployment audit trail. A failed test or vulnerability scan stops promotion before deployment. Kubernetes deployment uses readiness probes and Helm `--atomic`, so a bad release that never becomes ready is automatically rolled back. If a bad version reaches production and fails later, the rollback path is `helm rollback` or redeploying a previous known-good image tag.

For Terraform, I treat plan review as the main safety gate. Apply is manual and approval-gated. Rollback is not a magic command; it means reverting the infrastructure code to a previous known-good commit, reviewing the resulting plan, and applying carefully. For stateful services such as RDS, recovery may require snapshot or PITR restore rather than simply reverting Terraform.
