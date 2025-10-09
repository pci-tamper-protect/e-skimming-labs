#!/bin/bash

# Helper script to run tests for different skimmer variants
# Usage: ./run-variant-tests.sh [variant]
# Where variant is one of: base, obfuscated-base64, event-listener, websocket

set -e

VARIANT=${1:-base}

# Map short names to full variant names
case "$VARIANT" in
  base)
    SKIMMER_VARIANT="base"
    VARIANT_PATH="./vulnerable-site"
    ;;
  obfuscated-base64|obfuscated)
    SKIMMER_VARIANT="obfuscated-base64"
    VARIANT_PATH="./variants/obfuscated-base64/vulnerable-site"
    ;;
  event-listener|event)
    SKIMMER_VARIANT="event-listener-variant"
    VARIANT_PATH="./variants/event-listener-variant/vulnerable-site"
    ;;
  websocket|ws)
    SKIMMER_VARIANT="websocket-exfil"
    VARIANT_PATH="./variants/websocket-exfil/vulnerable-site"
    ;;
  *)
    echo "❌ Unknown variant: $VARIANT"
    echo ""
    echo "Usage: $0 [variant]"
    echo ""
    echo "Available variants:"
    echo "  base                - Standard checkout with basic skimmer"
    echo "  obfuscated-base64   - Base64 obfuscated skimmer"
    echo "  event-listener      - Event listener-based skimmer"
    echo "  websocket           - WebSocket exfiltration skimmer"
    exit 1
    ;;
esac

echo "🧪 Testing variant: $SKIMMER_VARIANT"
echo "📁 Variant path: $VARIANT_PATH"
echo ""

# Stop any running containers
echo "🛑 Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Start containers with the selected variant
echo "🚀 Starting containers with variant: $SKIMMER_VARIANT..."
export SKIMMER_VARIANT="$SKIMMER_VARIANT"
export VARIANT_PATH="$VARIANT_PATH"
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 5

# Check if services are up
if curl -s http://localhost:8080 > /dev/null && curl -s http://localhost:3000 > /dev/null 2>&1; then
  echo "✅ Services are running"
else
  echo "⚠️  Warning: Services may not be fully ready"
fi

# Run Playwright tests
echo ""
echo "🧪 Running Playwright tests for variant: $SKIMMER_VARIANT..."
cd test
SKIMMER_VARIANT="$SKIMMER_VARIANT" npx playwright test --reporter=list

echo ""
echo "✅ Test run complete!"
