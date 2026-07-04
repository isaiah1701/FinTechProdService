# Backup and Restore

Production would use RDS automated backups with point-in-time recovery.

Backup retention would be 7-35 days depending on environment and regulatory requirements.

RPO is approximately 5 minutes with RDS PITR.

RTO target for this service is under 1 hour, dependent on database size and restore validation.

Restore must be tested, not merely configured.

Restore process:

1. Restore into a new isolated RDS instance.
2. Validate schema and row counts.
3. Point a test deployment at the restored instance.
4. Verify `/readyz` works.
5. Verify `GET /api/accounts/acc_123` or a known production-safe smoke account.
6. Promote by changing application configuration only after validation.
7. Avoid overwriting production during restore testing.

Messaging recovery:

- unprocessed messages remain in SQS until retention expires
- in-flight messages return after visibility timeout if not acknowledged
- duplicate delivery is expected after failures
- the consumer must remain idempotent
- poison messages move to the DLQ after `maxReceiveCount = 3`
