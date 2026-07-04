# Zero-Downtime Rollout

The service supports zero-downtime rolling deployments by combining dependency-aware readiness, SIGTERM draining, a preStop delay, and a termination grace period.

`/healthz` and `/readyz` are intentionally different:

- `/healthz` says the process is alive.
- `/readyz` says the pod should receive traffic.

Readiness fails when Postgres is unreachable or when the application has started draining after SIGTERM.

Sequence:

1. A new ReplicaSet becomes ready before old pods are removed because `maxUnavailable` is `0` and `maxSurge` is `1`.
2. Kubernetes sends SIGTERM to an old pod.
3. The application signal handler marks the pod as draining.
4. `/readyz` immediately starts returning failure.
5. Kubernetes removes the pod from Service endpoints.
6. The `preStop` sleep gives endpoint and load-balancer propagation time.
7. Existing in-flight requests continue.
8. The pod exits cleanly before `terminationGracePeriodSeconds`.

The important Kubernetes settings are in `k8s/helm/bank-account-service/templates/deployment.yaml`:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
terminationGracePeriodSeconds: 45
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 10"]
readinessProbe:
  httpGet:
    path: /readyz
    port: http
livenessProbe:
  httpGet:
    path: /healthz
    port: http
```

This is deliberately boring. It avoids sending new requests to a pod that is terminating or cannot reach its database dependency.
