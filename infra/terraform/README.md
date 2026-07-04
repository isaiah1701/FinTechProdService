# Terraform

Terraform is authored to express the AWS production mapping.

It is formatted and validated locally. It is not applied for this assessment. The local kind workflow does not depend on Terraform output.

Validation:

```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

`terraform plan` requires real AWS credentials and real networking values. The included `envs/prod.tfvars.example` uses placeholders only.

Credential mapping:

- Secrets Manager stores the database secret metadata and, in a real pipeline, the secret value is inserted out-of-band.
- IRSA grants the service account read access to only that secret.
- RDS IAM authentication is enabled in the RDS module and the IRSA role includes a scoped `rds-db:connect` permission for `mal_account_app`.

## Resource Relationships For Non-Technical Reviewers

The Terraform is a blueprint for how the AWS pieces help each other:

| Resource | Relationship |
|---|---|
| ECR and EKS | ECR stores the approved service image. EKS pulls that immutable image and runs it as pods. |
| EKS and RDS | EKS runs the application. The application uses RDS Postgres for account data and idempotency records. |
| Secrets Manager, External Secrets, and IRSA | Secrets Manager stores database connection material. IRSA lets only this workload read that secret. External Secrets turns it into a Kubernetes Secret for the pod. |
| SQS and DLQ | SQS lets the service process audit side effects asynchronously. The DLQ captures bad messages after repeated failures so normal processing can continue. |
| Observability | Logs, metrics, dashboards, and alerts show whether customers can read account data quickly and reliably. |

This is intentionally simple: it gives a young bank speed while keeping releases traceable, credentials out of Git, account data durable, side effects retryable, and customer-impacting failures visible.
