#!/bin/bash
# Check what routes are configured in Traefik
# Usage: ./check-routes.sh [local|stg|prd]

set -e

ENVIRONMENT="${1:-local}"

if [ "$ENVIRONMENT" = "local" ]; then
  TRAEFIK_URL="http://localhost:9090"
  echo "🔍 Checking Traefik Routes (Local)"
  echo "===================================="
else
  if [ "$ENVIRONMENT" = "prd" ]; then
    PROJECT_ID="labs-prd"
  else
    PROJECT_ID="labs-stg"
  fi
  
  TRAEFIK_URL=$(gcloud run services describe "traefik-${ENVIRONMENT}" \
    --region=us-central1 \
    --project="${PROJECT_ID}" \
    --format="value(status.url)" 2>/dev/null || echo "")
  
  if [ -z "${TRAEFIK_URL}" ]; then
    echo "❌ Traefik service not found for ${ENVIRONMENT}"
    exit 1
  fi
  
  echo "🔍 Checking Traefik Routes (${ENVIRONMENT})"
  echo "==========================================="
fi

echo ""
echo "📋 Configured Routes:"
echo ""

# Get routers
if command -v jq >/dev/null 2>&1; then
  curl -sf "${TRAEFIK_URL}/api/http/routers" 2>/dev/null | jq -r '.[] | "  ✅ \(.name)\n     Rule: \(.rule)\n     Service: \(.service)\n     EntryPoints: \(.entryPoints | join(", "))\n"' || echo "  ⚠️  Could not fetch routers"
else
  curl -sf "${TRAEFIK_URL}/api/http/routers" 2>/dev/null || echo "  ⚠️  Could not fetch routers (install jq for better formatting)"
fi

echo ""
echo "🧪 Testing Endpoints:"
echo ""

# Test common endpoints
test_endpoint() {
  local endpoint="$1"
  local display_name="${2:-$endpoint}"
  STATUS=$(curl -sf -o /dev/null -w '%{http_code}' "${TRAEFIK_URL}${endpoint}" 2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "  ✅ ${display_name} → 200 OK"
  elif [ "$STATUS" = "404" ]; then
    echo "  ⚠️  ${display_name} → 404 Not Found (no route configured)"
  elif [ "$STATUS" = "401" ] || [ "$STATUS" = "403" ]; then
    echo "  🔒 ${display_name} → ${STATUS} (authentication required)"
  else
    echo "  ❌ ${display_name} → ${STATUS} (error)"
  fi
}

test_endpoint "/ping" "/ping"
test_endpoint "/api/rawdata" "/api/rawdata"
test_endpoint "/dashboard/" "/dashboard/"
test_endpoint "/" "/ (root)"
test_endpoint "/lab1" "/lab1"

echo ""
echo "💡 Note: 404 on root path (/) is normal if provider hasn't discovered Cloud Run services yet."
echo "   Check provider logs for authentication errors:"
if [ "$ENVIRONMENT" = "local" ]; then
  echo "   docker-compose -f docker-compose.sidecar-local.yml logs provider | grep ERROR"
else
  echo "   gcloud run services logs read traefik-${ENVIRONMENT} --container=provider | grep ERROR"
fi
