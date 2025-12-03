#!/bin/sh
set -e

QW_URL="http://quickwit:7280"
MAX_RETRIES=60
RETRY_DELAY=2

echo "▶ Installing dependencies..."
apk add --no-cache curl yq >/dev/null 2>&1

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

echo "▶ Processing index definitions..."

EXISTING_INDEXES=$(curl -sf "$QW_URL/api/v1/indexes" | grep -o '"index_id":"[^"]*"' | cut -d'"' -f4 || echo "")

INDEX_FILES=$(find /quickwit/config/indexes -type f \( -name "*.json" -o -name "*.yml" -o -name "*.yaml" \) 2>/dev/null)

if [ -z "$INDEX_FILES" ]; then
  echo "⚠ No index files found in /quickwit/config/indexes/"
  echo "   Searched for: *.json, *.yml, *.yaml"
  echo "   Directory contents:"
  ls -la /quickwit/config/indexes/ || true
  find /quickwit/config/indexes -type f || true
  exit 0
fi

# Process each index file
for INDEX_FILE in $INDEX_FILES; do
  echo ""
  echo "▶ Processing: $INDEX_FILE"

  # Extract index_id based on file type
  if echo "$INDEX_FILE" | grep -q '\.json$'; then
    INDEX_ID=$(grep -o '"index_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$INDEX_FILE" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  else
    # YAML file
    INDEX_ID=$(yq eval '.index_id' "$INDEX_FILE" 2>/dev/null)
  fi

  if [ -z "$INDEX_ID" ] || [ "$INDEX_ID" = "null" ]; then
    echo "✗ Failed to extract index_id from $INDEX_FILE"
    echo "   File contents:"
    head -20 "$INDEX_FILE"
    continue
  fi

  echo "  Index ID: $INDEX_ID"

  # Check if index already exists
  if echo "$EXISTING_INDEXES" | grep -qx "$INDEX_ID"; then
    echo "✔ Index '$INDEX_ID' already exists. Skipping."
    continue
  fi

  # Create the index
  echo "▶ Creating index: $INDEX_ID"

  # Convert YAML to JSON if needed and POST
  if echo "$INDEX_FILE" | grep -q '\.json$'; then
    # JSON file - POST directly
    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" \
      -X POST \
      -H "Content-Type: application/json" \
      --data @"$INDEX_FILE" \
      "$QW_URL/api/v1/indexes")
  else
    # YAML file - convert to JSON first with proper string handling
    echo "  Converting YAML to JSON..."
    # Use yq and ensure version is quoted as string
    yq eval -o=json -I=0 "$INDEX_FILE" | \
      sed 's/"version":\s*\([0-9.]*\)/"version":"\1"/g' | \
      sed 's/"version":"\([0-9.]*\)"/"version":"\1"/g' > /tmp/index.json

    echo "  Generated JSON (first 50 lines):"
    head -50 /tmp/index.json
    echo ""

    HTTP_CODE=$(curl -s -o /tmp/response.txt -w "%{http_code}" \
      -X POST \
      -H "Content-Type: application/json" \
      --data @/tmp/index.json \
      "$QW_URL/api/v1/indexes")
  fi

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✔ Successfully created index '$INDEX_ID' (HTTP $HTTP_CODE)"
  else
    echo "✗ Failed to create index '$INDEX_ID' (HTTP $HTTP_CODE)"
    echo "   Response:"
    cat /tmp/response.txt
    echo ""
    exit 1
  fi

  sleep 1
done

echo ""
echo "✔ All indexes processed successfully!"