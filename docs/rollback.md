# Rollback

Production-equivalent deploys require manual approval through GitHub Environments.

## Versioning And Auditability

| Layer | Version/Audit mechanism | Failure gate | Rollback path |
|---|---|---|---|
| Docker image | Git SHA image tag | Unit tests and Trivy HIGH/CRITICAL scan | Redeploy previous known-good image tag |
| Kubernetes | Helm release revision and image tag | Helm `--atomic`, readiness probes, rollout status | `helm rollback` or redeploy previous image tag |
| Terraform | Git commit, reviewed plan, state versioning in real AWS | fmt, validate, plan review, manual approval | Revert infra commit, review plan, apply; restore stateful data from backup/PITR where needed |

## Docker Image Rollback

Docker rollback is deployment rollback: rebuilds are not needed if a previous known-good immutable image tag exists.

```bash
helm upgrade --install bank-account-service k8s/helm/bank-account-service \
  -n bank \
  -f k8s/helm/bank-account-service/values-prod.yaml \
  --set image.repository="${ECR_REGISTRY}/${ECR_REPOSITORY}" \
  --set image.tag=<previous_good_git_sha> \
  --atomic \
  --timeout 5m
```

The image tag should be a Git SHA. Do not use bare `latest` for production rollback.

## Kubernetes Rollback

Kubernetes rollout safety comes from readiness probes, liveness probes, `maxUnavailable: 0`, `preStop`, `terminationGracePeriodSeconds`, and Helm `--atomic`.

Readiness is the important rollout gate. If the new pods never become ready, Helm `--atomic` rolls back to the previous release. Liveness is for restarting unhealthy containers; it does not by itself protect a rollout.

Inspect release history:

```bash
helm history bank-account-service -n bank
```

Rollback by Helm revision:

```bash
helm rollback bank-account-service <REVISION> -n bank
kubectl rollout status deployment/bank-account-service -n bank --timeout=120s
```

Rollback by immutable image tag:

```bash
helm upgrade --install bank-account-service k8s/helm/bank-account-service \
  -n bank \
  -f k8s/helm/bank-account-service/values-prod.yaml \
  --set image.tag=<previous_good_git_sha> \
  --atomic \
  --timeout 5m
```

## Terraform Rollback

Terraform does not have a universal rollback button.

Terraform rollback is normally performed by reverting the infrastructure code to the previous known-good commit, reviewing the resulting plan, and applying that plan after approval.

Example:

```bash
git revert <bad_commit_sha>
cd infra/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

For destructive or stateful resources such as RDS, rollback must be handled carefully. The plan must be reviewed to avoid accidental data loss. RDS recovery may require restoring from snapshot or point-in-time recovery rather than simply reverting Terraform code.

State versioning should be enabled on the remote backend bucket in a real AWS environment. For this assessment, backend config is documented but not applied.
