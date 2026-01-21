#!/bin/bash
# Quick test script for Traefik Sidecar Deployment
# Usage: ./test-deployment.sh [stg|prd]

set -e

ENVIRONMENT="${1:-stg}"
PROJECT_ID="labs-${ENVIRONMENT}"
REGION="us-central1"

echo "🧪 Testing Traefik Sidecar Deployment (${ENVIRONMENT})"
echo ""

# Get URLs
echo "🔍 Getting service URLs..."
MAIN_URL=$(gcloud run services describe traefik-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null || echo "")

DASHBOARD_URL=$(gcloud run services describe traefik-dashboard-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null || echo "")

if [ -z "${MAIN_URL}" ]; then
  echo "❌ Main Traefik service not found. Deploy first: ./deploy-sidecar.sh ${ENVIRONMENT}"
  exit 1
fi

if [ -z "${DASHBOARD_URL}" ]; then
  echo "⚠️  Dashboard service not found. It may not be deployed yet."
fi

echo "📋 Service URLs:"
echo "   Main Traefik: ${MAIN_URL}"
if [ -n "${DASHBOARD_URL}" ]; then
  echo "   Dashboard: ${DASHBOARD_URL}"
fi
echo ""

# Test 1: Main Traefik health check
echo "1️⃣  Testing main Traefik health check..."
if curl -sf --max-time 10 "${MAIN_URL}/ping" > /dev/null 2>&1; then
  echo "   ✅ Main Traefik is healthy"
else
  echo "   ❌ Main Traefik health check failed"
  echo "      URL: ${MAIN_URL}/ping"
  exit 1
fi

# Test 2: Provider logs
echo "2️⃣  Checking provider sidecar logs..."
PROVIDER_LOGS=$(gcloud run services logs read traefik-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --container=provider \
  --limit=20 \
  --format="value(textPayload)" 2>/dev/null || echo "")

if echo "${PROVIDER_LOGS}" | grep -qi "routes.*generated\|starting.*provider\|generating.*traefik"; then
  echo "   ✅ Provider is generating routes"
  # Show last route generation
  echo "${PROVIDER_LOGS}" | grep -i "routes\|generated\|summary" | tail -3 | sed 's/^/      /'
else
  echo "   ⚠️  Provider logs not found or no route generation detected"
  echo "      Check logs: gcloud run services logs read traefik-${ENVIRONMENT} --container=provider"
fi

# Test 3: Dashboard accessibility
if [ -n "${DASHBOARD_URL}" ]; then
  echo "3️⃣  Testing dashboard accessibility..."
  if curl -sf --max-time 10 "${DASHBOARD_URL}/dashboard/" > /dev/null 2>&1; then
    echo "   ✅ Dashboard is accessible"
  else
    echo "   ⚠️  Dashboard may require authentication or is not ready"
    echo "      URL: ${DASHBOARD_URL}/dashboard/"
  fi
else
  echo "3️⃣  Skipping dashboard test (service not deployed)"
fi

# Test 4: Main Traefik logs
echo "4️⃣  Checking main Traefik logs..."
TRAEFIK_LOGS=$(gcloud run services logs read traefik-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --container=traefik \
  --limit=20 \
  --format="value(textPayload)" 2>/dev/null || echo "")

if echo "${TRAEFIK_LOGS}" | grep -qi "configuration.*loaded\|file provider\|watching"; then
  echo "   ✅ Main Traefik is running and watching routes"
else
  echo "   ⚠️  Main Traefik logs not found or configuration not loaded"
  echo "      Check logs: gcloud run services logs read traefik-${ENVIRONMENT} --container=traefik"
fi

# Test 5: Check service status
echo "5️⃣  Checking service status..."
MAIN_STATUS=$(gcloud run services describe traefik-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --format="value(status.conditions[0].status)" 2>/dev/null || echo "Unknown")

if [ "${MAIN_STATUS}" = "True" ]; then
  echo "   ✅ Main Traefik service is Ready"
else
  echo "   ⚠️  Main Traefik service status: ${MAIN_STATUS}"
fi

if [ -n "${DASHBOARD_URL}" ]; then
  DASHBOARD_STATUS=$(gcloud run services describe traefik-dashboard-${ENVIRONMENT} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --format="value(status.conditions[0].status)" 2>/dev/null || echo "Unknown")
  
  if [ "${DASHBOARD_STATUS}" = "True" ]; then
    echo "   ✅ Dashboard service is Ready"
  else
    echo "   ⚠️  Dashboard service status: ${DASHBOARD_STATUS}"
  fi
fi

echo ""
echo "✅ Basic tests completed!"
echo ""
echo "💡 Next steps:"
echo "   - View detailed logs:"
echo "     gcloud run services logs read traefik-${ENVIRONMENT} --region=${REGION} --project=${PROJECT_ID} --container=provider"
echo "     gcloud run services logs read traefik-${ENVIRONMENT} --region=${REGION} --project=${PROJECT_ID} --container=traefik"
if [ -n "${DASHBOARD_URL}" ]; then
  echo "     gcloud run services logs read traefik-dashboard-${ENVIRONMENT} --region=${REGION} --project=${PROJECT_ID}"
fi
echo ""
echo "   - Test routing (requires auth token):"
echo "     TOKEN=\$(gcloud auth print-identity-token)"
echo "     curl -H \"Authorization: Bearer \${TOKEN}\" ${MAIN_URL}/"
echo ""
if [ -n "${DASHBOARD_URL}" ]; then
  echo "   - View dashboard:"
  echo "     ${DASHBOARD_URL}/dashboard/"
fi
