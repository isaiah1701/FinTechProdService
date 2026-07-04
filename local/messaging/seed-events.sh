#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-eu-west-2}"
ENDPOINT_URL="${ENDPOINT_URL:-http://localhost:4566}"

aws --endpoint-url "$ENDPOINT_URL" sqs create-queue --queue-name mal-account-events >/dev/null
aws --endpoint-url "$ENDPOINT_URL" sqs send-message \
  --queue-url "$ENDPOINT_URL/000000000000/mal-account-events" \
  --message-body '{"event_id":"evt_123","account_id":"acc_123","action":"ACCOUNT_VIEWED"}' >/dev/null

echo "Seeded LocalStack SQS queue mal-account-events"
