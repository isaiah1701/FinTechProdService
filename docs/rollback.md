# Rollback

Rollback by Helm revision:

```bash
helm rollback mal-account-service <revision>
```

Rollback by immutable image tag:

```bash
helm upgrade --install mal-account-service k8s/helm/mal-account-service \
  -f k8s/helm/mal-account-service/values-prod.yaml \
  --set image.tag=<previous_good_sha>
```

The image tag should be a Git SHA. Do not use bare `latest` for production rollback.
