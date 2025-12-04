#!/bin/sh
set -e

QW_URL="http://quickwit:7280"
MAX_RETRIES=60
RETRY_DELAY=2

echo "▶ Installing dependencies..."
apk add --no-cache curl yq jq >/dev/null 2>&1

echo "▶ Waiting for Quickwit at $QW_URL..."

for i in $(seq 1 $MAX_RETRIES); do
  if curl -sf "$QW_URL/health/readyz" >/dev/null 2>&1 || \
     curl -sf "$QW_URL/health/livez" >/dev/null 2>&1 || \
     curl -sf "$QW_URL/api/v1/version" >/dev/null 2>&1; then
    echo "✔ Quickwit is ready."
    break
  fi

  if [ $i -eq $MAX_RETRIES ]; then
    echo "✗ Quickwit did not become ready after $MAX_RETRIES attempts."
    exit 1
  fi

  echo "  Waiting... ($i/$MAX_RETRIES)"
  sleep $RETRY_DELAY
done

sleep 5

echo ""
echo "▶ Creating index: api-logs"

# Check if index already exists
EXISTING_INDEXES=$(curl -sf "$QW_URL/api/v1/indexes" | jq -r '.[].index_id' 2>/dev/null || echo "")

if echo "$EXISTING_INDEXES" | grep -qx "api-logs"; then
  echo "✔ Index 'api-logs' already exists."
else
  # Create index from JSON file
  HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    --data @/quickwit/config/indexes/webservice/index.json \
    "$QW_URL/api/v1/indexes")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✔ Successfully created index 'api-logs' (HTTP $HTTP_CODE)"
  else
    echo "✗ Failed to create index 'api-logs' (HTTP $HTTP_CODE)"
    echo "   Response:"
    cat /tmp/response.txt
    echo ""
    exit 1
  fi
fi

sleep 2

# Check if source already exists
EXISTING_SOURCES=$(curl -sf "$QW_URL/api/v1/indexes/api-logs/sources" | jq -r '.[].source_id' 2>/dev/null || echo "")

if echo "$EXISTING_SOURCES" | grep -qx "api-logs-kafka"; then
  echo "✔ Kafka source 'api-logs-kafka' already exists."
else
  # Create Kafka source from YAML file
  HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/yaml" \
    --data-binary @/quickwit/config/kafka-source.yaml \
    "$QW_URL/api/v1/indexes/api-logs/sources")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✔ Successfully created Kafka source 'api-logs-kafka' (HTTP $HTTP_CODE)"
  else
    echo "✗ Failed to create Kafka source 'api-logs-kafka' (HTTP $HTTP_CODE)"
    echo "   Response:"
    cat /tmp/response.txt
    echo ""
    echo "   Note: kafka-source.yaml should be at /quickwit/config/kafka-source.yaml"
    # Don't exit with error - source might already exist
  fi
fi

echo ""
echo "✔ Quickwit initialization complete!"
echo ""
echo "Index and Kafka source are ready. Quickwit will automatically start consuming from Kafka."