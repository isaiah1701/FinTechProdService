# Local Messaging

LocalStack represents SQS for local development. The service's production mapping is AWS SQS with a DLQ and `maxReceiveCount = 3`.

Create the local queue with:

```bash
./local/messaging/seed-events.sh
```
