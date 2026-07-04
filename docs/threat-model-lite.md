# Threat Model Lite

Main risks and controls:

| Risk | Control |
|---|---|
| Secrets exposure | Secrets Manager, External Secrets, no static AWS keys |
| Over-privileged DB user | `bank_account_app` has no DDL, ownership, or superuser rights |
| Unsafe pod runtime | non-root numeric user, no privilege escalation, read-only root filesystem, dropped capabilities |
| Missing network restrictions | NetworkPolicy demonstrates constrained ingress and required egress |
| Customer data in logs or metrics | structured logs, no account balances or names in labels, no credentials in logs |
| Supply chain image vulnerabilities | Docker workflow scans image with Trivy and fails on HIGH/CRITICAL |
| CI credential leakage | GitHub OIDC instead of committed cloud keys |
