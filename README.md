# mal-account-service-platform

Senior DevOps/SRE take-home repository for Mal, framed as an early-stage bank where speed matters but reliability is part of the product. The application is intentionally tiny; the assessment value is in the platform controls around it.

The local path proves the workload behaviour on kind. The AWS path is expressed as Terraform and production Helm values, but is intentionally not applied for this assessment.

## Runtime Targets

| Target | Purpose | Applied? |
|---|---|---|
| kind | Local validation of Kubernetes workload | Yes, optional |
| Docker Compose | Local Postgres/SQS/observability dependencies | Yes |
| AWS Terraform | Production-shaped infrastructure mapping | No |
| GitHub Actions | CI/CD structure and controls | Authored only unless configured |

## Assessment Requirement Map

| Requirement | Location |
|---|---|
| Container | `app/Dockerfile` |
| Kubernetes workload | `k8s/helm/mal-account-service/` |
| Zero-downtime rollout | `docs/zero-downtime-rollout.md` |
| Postgres and DB grants | `local/postgres/` and `docs/database-access.md` |
| Credential handling | `k8s/helm/mal-account-service/templates/externalsecret.yaml` |
| Messaging consumer | `app/src/mal_account_service/consumer.py` |
| Idempotency | `app/src/mal_account_service/idempotency.py` |
| CI/CD | `.github/workflows/` |
| Terraform | `infra/terraform/` |
| Observability | `observability/` and `local/prometheus/` |

## Local Run Path

Start local dependencies:

```bash
export MAL_POSTGRES_OWNER_PASSWORD='<set-locally>'
export MAL_ACCOUNT_APP_PASSWORD='<set-locally>'
export MAL_GRAFANA_ADMIN_PASSWORD='<set-locally>'
make local-up
```

Build and deploy to kind:

```bash
kind create cluster --name mal-platform
docker build -t mal-account-service:local -f app/Dockerfile .
kind load docker-image mal-account-service:local --name mal-platform
export DATABASE_URL="postgresql://mal_account_app:${MAL_ACCOUNT_APP_PASSWORD}@172.17.0.1:5432/mal_accounts"
make kind-secret
make kind-deploy
```

Port-forward:

```bash
kubectl port-forward svc/mal-account-service 8080:8080
```

Try the service:

```bash
curl localhost:8080/healthz
curl localhost:8080/readyz
curl localhost:8080/metrics
curl localhost:8080/api/accounts/acc_123
```

On Docker Desktop, set the local database host before creating the Kubernetes Secret:

```bash
export DATABASE_URL="postgresql://mal_account_app:${MAL_ACCOUNT_APP_PASSWORD}@host.docker.internal:5432/mal_accounts"
make kind-secret
```

Do not commit local secret values. `.env` is ignored; `.env.example` lists the required variable names only.

## Validation Commands

```bash
make test
make docker-build
make helm-lint
make helm-template
make terraform-validate
```

Terraform validation only formats and validates the AWS-shaped code:

```bash
cd infra/terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

## Local To AWS Mapping

| Local | AWS |
|---|---|
| Docker image loaded into kind | ECR |
| kind Kubernetes | EKS |
| Docker Compose Postgres | RDS Postgres |
| LocalStack SQS | SQS + DLQ |
| Helm chart | EKS workload |
| Local Kubernetes Secret | Secrets Manager + External Secrets |
| ServiceAccount | IRSA / EKS Pod Identity |
| Prometheus/Grafana | AMP/Grafana/Datadog |

## Architecture In Plain English

This is the system relationship for non-technical reviewers:

| Resource | What it does | How it helps the others |
|---|---|---|
| Docker image | Packages the account service into a repeatable release artifact | CI builds it once, scans it, and tags it with the Git SHA so every deployment is traceable |
| ECR | Stores production Docker images | EKS pulls the exact approved image from ECR when a release is deployed |
| EKS | Runs the service pods | It keeps multiple copies available, replaces pods during rollouts, and routes traffic only to ready pods |
| RDS Postgres | Stores accounts, audit events, and processed event IDs | The service reads account data from RDS; the consumer uses RDS to make message handling idempotent |
| Secrets Manager | Stores database connection material outside the repo | External Secrets and IRSA let the pod receive only the secret it needs, without static AWS keys |
| IRSA / EKS Pod Identity | Gives the pod a narrow AWS identity | The pod can read its database secret, consume its SQS queue, and connect as the intended database user without broad cloud access |
| SQS | Holds background messages for asynchronous work | Account reads stay fast because audit side effects can be retried separately by consumers |
| DLQ | Holds poison messages after repeated failures | Bad messages stop blocking normal processing and can be inspected safely |
| Prometheus/Grafana/alerts | Shows request rate, errors, latency, and SLO burn | Engineers can see whether customers are failing to read account state and respond before trust is damaged |
| Terraform | Describes the AWS production shape | Reviewers can see how the resources fit together even though the assessment is not applied to AWS |

The important flow is: CI builds and scans an image, stores it in ECR, EKS runs that image, the pod reads credentials through Secrets Manager/IRSA, the service reads account data from RDS, background side effects go through SQS, repeated bad messages land in a DLQ, and observability tells the team whether account reads are reliable for customers.

## CI/CD Split

All pipelines live in `.github/workflows`:

| Workflow | Purpose |
|---|---|
| `docker.yml` | Python tests, image build, Trivy scan, immutable GHCR push on `main` |
| `kubernetes.yml` | Helm lint/template and optional manual Helm deploy |
| `terraform-plan.yml` | Terraform fmt/init/validate and optional OIDC-backed plan |
| `terraform-apply.yml` | Manual production-gated Terraform apply skeleton |

## Banking Reliability Framing

For an early-stage bank, platform choices should help the team ship quickly without hiding customer-impact risk. This repo therefore prioritises:

- dependency-aware readiness so account reads are not routed to unhealthy pods
- immutable image tags and scan gates so releases are traceable
- least-privilege database access so an app compromise has a small blast radius
- idempotent queue handling so retries do not duplicate customer-visible side effects
- RED metrics and SLO alerts tied to account lookup success, because slow or failing reads become support contacts, failed onboarding checks, and loss of trust
