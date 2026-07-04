# Decisions and Trade-offs

Context: this is framed for an early-stage bank. The platform needs to let a small team move quickly, but account lookup reliability is business-critical because slow or failed reads directly affect customer trust, operations, onboarding checks, and support load.

## 1. Biggest decisions

### Decision 1: Dependency-aware readiness and graceful draining

I separated liveness from readiness. `/healthz` only proves the process is alive. `/readyz` fails when Postgres is unreachable or when the pod is draining after SIGTERM.

Trade-off: this adds a small amount of application logic, but it prevents traffic being sent to pods that cannot safely serve requests.

### Decision 2: SQS-style queue with idempotent consumer

I chose an SQS-style queue because the service only needs asynchronous side effects, not global ordering or stream replay. SQS gives simple retry, visibility timeout, horizontal consumer scaling, and DLQ behaviour.

Trade-off: SQS does not provide Kafka-style replay or rich event-stream semantics. If the domain later required ordered event history or replay, I would reconsider Kafka or another log-based broker.

### Decision 3: No PgBouncer locally; transaction pooling in production if needed

I did not add PgBouncer to the local assessment because the service is tiny and extra moving parts would reduce clarity. In production I would consider PgBouncer in transaction pooling mode if pod count or connection churn threatened RDS connection limits.

Trade-off: transaction pooling improves connection efficiency but can break workloads that rely on session-level database state. I would avoid session features in the app before adopting it.

## 2. SLO and alerting

Service SLO:

- SLI: percentage of successful account lookup requests.
- Success definition: `GET /api/accounts/{id}` returns non-5xx within 300ms.
- Target: 99.9% over 30 days.
- User impact: customers and internal systems need account reads to complete reliably and quickly.

Paging:

Use a multi-window burn-rate alert on the error-budget consumption for account lookups rather than a single static threshold.

The one alert I would keep:

Page when the account lookup SLO is burning too quickly across both a short and long window:

- fast burn: 5xx/slow responses breach budget over 5 minutes
- sustained burn: the same symptom remains elevated over 1 hour

This catches both sharp incidents and gradual degradation that may not trip a single CPU or latency threshold.

Business link: the alert is tied to account lookup success and latency because those are user-facing banking symptoms. CPU is useful debugging context, but customers feel failed or slow account reads, not CPU saturation.

## 3. Least privilege and blast radius

The application connects to Postgres as `mal_account_app`.

This role can:

- connect to the application database
- use the application schema
- select, insert, and update its own required tables
- insert processed event IDs and audit records

This role cannot:

- create, alter, or drop tables
- manage roles
- act as database owner
- act as superuser
- access unrelated schemas
- perform unrestricted DDL

Workload identity model:

In production, the pod would use IRSA or EKS Pod Identity. It would only be allowed to read the specific Secrets Manager secret needed for the database credential. It would not receive static AWS keys.

If a pod is compromised through RCE, the attacker can reach only what the pod can reach:

- the application database with the limited runtime DB role
- the specific database secret exposed to this workload
- network destinations allowed by NetworkPolicy and AWS security groups
- the SQS queue actions explicitly granted to the workload

The design deliberately denies broad AWS permissions, database ownership, DDL permissions, unrelated secrets, unrestricted pod privileges, and privileged container escape paths such as root user, privilege escalation, and Linux capabilities.

## 4. Recovery

Postgres:

Production would use RDS automated backups with point-in-time recovery.

Target RPO: approximately 5 minutes.

Reasoning: account reads are important, but the service shown here is not a payment ledger. RDS PITR gives a practical recovery point without building a custom backup system.

Target RTO: under 1 hour.

Reasoning: restoring a managed RDS instance, validating the restored data, rotating application configuration, and confirming application health should be achievable within this window for this service size.

How to prove restore works:

- restore into a new isolated RDS instance
- run schema and row-count checks
- run an application smoke test against the restored database
- verify `/readyz` and `GET /api/accounts/acc_123`
- document the steps and run them regularly
- never test restore by overwriting production

Messaging:

During an outage, unprocessed messages remain in the queue until their retention period expires. In-flight messages become visible again after the visibility timeout if not acknowledged. Consumers must be idempotent because messages may be delivered more than once after recovery.

Poison messages move to the DLQ after `maxReceiveCount = 3`. Operators inspect, fix, replay, or discard them depending on the failure type.

## 5. What I cut

For time, I deprioritised full AWS deployment, full LocalStack end-to-end validation, complex dashboard polish, service mesh, ArgoCD, advanced policy-as-code, a full migration framework, and production-grade load testing.

What I would implement first in a real rollout:

1. database migrations with Alembic or Flyway
2. real External Secrets integration
3. multi-window SLO burn-rate alerts in the live monitoring stack
4. restore drill automation
5. image signing and SBOM generation
6. Kyverno or OPA admission policies
7. load testing to tune HPA and database pooling

Terraform is authored and validated locally but not applied. The local stack demonstrates the behaviour; AWS production mapping is documented and expressed in Terraform.
