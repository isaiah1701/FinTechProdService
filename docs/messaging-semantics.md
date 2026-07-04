# Messaging Semantics

The service uses an SQS-style queue for asynchronous side effects. The local repo includes LocalStack only as a lightweight stand-in; the important part is the consumer behaviour.

SQS fits this service because asynchronous side effects do not need global ordering, retry/DLQ behaviour is native, and consumers can scale horizontally.

## Idempotency

Duplicate event delivery must create one audit event only.

Mechanism:

1. Start a database transaction.
2. Insert `event_id` into `processed_events`.
3. If the insert succeeds, write the audit event.
4. If the insert conflicts, skip the side effect.
5. Duplicate event delivery causes the side effect exactly once.

This is implemented in `app/src/mal_account_service/consumer.py` and `app/src/mal_account_service/idempotency.py`.

## Poison Messages

Transient failures such as database timeouts should be retried.

Malformed or invalid messages should not be retried forever.

After `maxReceiveCount = 3`, the message should move to a DLQ.

Operators should inspect DLQ messages, fix the cause, then replay or discard them intentionally.

During an outage, unprocessed messages remain in the queue until retention expires. In-flight messages become visible again after the visibility timeout if they are not acknowledged. This is why the consumer is idempotent.
