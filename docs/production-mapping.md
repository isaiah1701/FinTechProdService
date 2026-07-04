# Production Mapping

| Local | AWS |
|---|---|
| kind | EKS |
| local image loaded into kind | ECR |
| Docker Compose Postgres | RDS Postgres |
| LocalStack SQS | SQS + DLQ |
| local Kubernetes Secret | Secrets Manager + External Secrets |
| ServiceAccount | IRSA / EKS Pod Identity |
| Prometheus/Grafana | AMP/Grafana/Datadog |

Terraform expresses this production shape, but it is not applied for the assessment.

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
