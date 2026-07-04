# Production Mapping and Runbook

This document shows how to run the platform locally on kind, how the local pieces map to AWS, and how the same workload would be promoted through ECR and EKS.

Terraform expresses the AWS production shape, but it is not applied automatically for this assessment.

## Local To AWS Mapping

| Local | AWS |
|---|---|
| Docker image loaded into kind | ECR |
| kind Kubernetes | EKS |
| Docker Compose Postgres | RDS Postgres |
| LocalStack SQS | SQS + DLQ |
| local Kubernetes Secret | Secrets Manager + External Secrets |
| ServiceAccount | IRSA / EKS Pod Identity |
| Prometheus/Grafana | AMP/Grafana/Datadog |

## Architecture In Plain English

Think of the platform as a set of cooperating parts:

| Resource | Plain-English role | Relationship |
|---|---|---|
| ECR | The approved image store | CI puts the scanned service image here; EKS pulls the exact Git-SHA image from it |
| EKS | The service runtime | Runs the account service, replaces pods safely during releases, and stops sending traffic to pods that are not ready |
| RDS Postgres | The system of record for this tiny service | Stores accounts, audit rows, and processed event IDs used for idempotency |
| Secrets Manager | The production secret vault | Holds database connection material outside Git and outside container images |
| External Secrets | The bridge from AWS secrets to Kubernetes | Creates the Kubernetes Secret the pod reads at runtime |
| IRSA / EKS Pod Identity | The pod's limited AWS identity | Allows only the required secret, queue, and database-auth access |
| SQS | The async work queue | Lets side effects happen outside the request path so customer account reads stay fast |
| DLQ | The failure quarantine | Keeps malformed messages from being retried forever and blocking normal work |
| Prometheus/Grafana/alerts | The reliability feedback loop | Shows whether customers can read account state quickly and reliably |
| Terraform | The AWS blueprint | Describes how these resources would be created and connected in production |

For an early-stage bank, the relationship matters more than the number of tools. ECR gives EKS a trusted image, EKS gives the service a stable runtime, RDS gives it durable account data, SQS keeps slower side effects off the customer path, secrets and IRSA reduce blast radius, and observability tells the team when customer trust is at risk.

## Bring Up Locally On kind

Prerequisites:

- Docker
- Docker Compose
- kind
- kubectl
- Helm
- Python 3.12+ for tests

Set local-only secret values in your shell. Do not commit these values:

```bash
export BANK_POSTGRES_OWNER_PASSWORD='<set-locally>'
export BANK_ACCOUNT_APP_PASSWORD='<set-locally>'
export BANK_GRAFANA_ADMIN_PASSWORD='<set-locally>'
export BANK_POSTGRES_PORT=55432
```

Start local dependencies:

```bash
make local-up
```

Create the kind cluster:

```bash
kind create cluster --name bank-platform
```

Build the local image and load it into kind:

```bash
docker build -t bank-account-service:local -f app/Dockerfile .
kind load docker-image bank-account-service:local --name bank-platform
```

Create the local Kubernetes Secret from your shell value:

```bash
export DATABASE_URL="postgresql://bank_account_app:${BANK_ACCOUNT_APP_PASSWORD}@172.17.0.1:${BANK_POSTGRES_PORT:-55432}/bank_accounts"
make kind-secret
```

On Docker Desktop, use `host.docker.internal` instead:

```bash
export DATABASE_URL="postgresql://bank_account_app:${BANK_ACCOUNT_APP_PASSWORD}@host.docker.internal:${BANK_POSTGRES_PORT:-55432}/bank_accounts"
make kind-secret
```

Deploy the Helm chart:

```bash
make kind-deploy
```

Check pods and service:

```bash
kubectl get pods
kubectl get svc bank-account-service
```

Port-forward and call the service:

```bash
kubectl port-forward svc/bank-account-service 18080:8080
curl localhost:18080/healthz
curl localhost:18080/readyz
curl localhost:18080/metrics
curl localhost:18080/api/accounts/acc_123
```

Clean up local runtime:

```bash
kind delete cluster --name bank-platform
make local-down
```

## Validate Before Review

Run the same checks the pipelines run:

```bash
make test
make docker-build
make helm-lint
make helm-template
make terraform-validate
```

Terraform validation is local-only:

```bash
cd infra/terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

## Production Promotion To ECR And EKS

The intended AWS promotion path is:

1. Terraform defines ECR, EKS, RDS, Secrets Manager, SQS, DLQ, IAM, and observability resources.
2. The Docker workflow builds and scans the image.
3. If AWS GitHub variables are configured, the Docker workflow also pushes the same immutable Git-SHA image to ECR.
4. The Kubernetes workflow renders and validates Helm.
5. A manually approved Kubernetes workflow deploys the ECR image to EKS with `helm upgrade --install`.

Required GitHub Environment or repository variables for the cloud path:

| Variable | Example |
|---|---|
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::000000000000:role/bank-github-actions` |
| `ECR_REGISTRY` | `000000000000.dkr.ecr.eu-west-2.amazonaws.com` |
| `ECR_REPOSITORY` | `bank-account-service` |

The Docker workflow pushes:

```text
${ECR_REGISTRY}/${ECR_REPOSITORY}:${GITHUB_SHA}
```

The Kubernetes workflow deploys the same immutable SHA tag:

```bash
helm upgrade --install bank-account-service k8s/helm/bank-account-service \
  -n bank \
  --create-namespace \
  -f k8s/helm/bank-account-service/values-prod.yaml \
  --set image.repository="${ECR_REGISTRY}/${ECR_REPOSITORY}" \
  --set image.tag="${GITHUB_SHA}" \
  --atomic \
  --timeout 5m
```

## Manual AWS Command Shape

These commands show the equivalent manual flow. They are documentation only unless you provide real AWS account values and credentials.

Authenticate Docker to ECR:

```bash
aws ecr get-login-password --region eu-west-2 \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
```

Build, tag, and push:

```bash
export IMAGE_TAG="$(git rev-parse HEAD)"
docker build -t bank-account-service:"${IMAGE_TAG}" -f app/Dockerfile .
docker tag bank-account-service:"${IMAGE_TAG}" "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
docker push "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
```

Point kubectl at EKS:

```bash
aws eks update-kubeconfig --name bank-platform --region eu-west-2
```

Deploy:

```bash
helm upgrade --install bank-account-service k8s/helm/bank-account-service \
  -n bank \
  --create-namespace \
  -f k8s/helm/bank-account-service/values-prod.yaml \
  --set image.repository="${ECR_REGISTRY}/${ECR_REPOSITORY}" \
  --set image.tag="${IMAGE_TAG}" \
  --atomic \
  --timeout 5m
```

Run smoke checks:

```bash
kubectl rollout status deployment/bank-account-service -n bank --timeout=120s
kubectl port-forward svc/bank-account-service -n bank 8080:8080
curl localhost:8080/healthz
curl localhost:8080/readyz
curl localhost:8080/api/accounts/acc_123
```

## Production Secret Path

Local kind uses a Kubernetes Secret created at runtime from `DATABASE_URL`.

Production should use this path:

1. AWS Secrets Manager stores the database connection material.
2. External Secrets Operator reads the secret from AWS.
3. IRSA or EKS Pod Identity allows only this ServiceAccount to read that secret.
4. External Secrets creates the Kubernetes Secret.
5. The pod receives `DATABASE_URL` from the Kubernetes Secret.

No plaintext production credential should be committed to the repository or baked into an image.

## Rollback

Rollback by Helm revision:

```bash
helm rollback bank-account-service <revision> -n bank
```

Rollback by image SHA:

```bash
helm upgrade --install bank-account-service k8s/helm/bank-account-service \
  -n bank \
  -f k8s/helm/bank-account-service/values-prod.yaml \
  --set image.repository="${ECR_REGISTRY}/${ECR_REPOSITORY}" \
  --set image.tag="<previous_good_sha>" \
  --atomic \
  --timeout 5m
```
