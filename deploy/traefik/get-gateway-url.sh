#!/bin/bash
# Get Traefik Gateway URL
# Usage: ./get-gateway-url.sh [stg|prd|local]

set -e

ENVIRONMENT="${1:-stg}"

if [ "$ENVIRONMENT" = "local" ]; then
  echo "🌐 Traefik Gateway (Local Sidecar Simulation)"
  echo "=============================================="
  echo ""
  echo "   Traefik Gateway: http://localhost:9090"
  echo "   Dashboard: http://localhost:9091/dashboard/"
  echo "   API: http://localhost:9090/api/rawdata"
  echo ""
  echo "💡 To start local simulation:"
  echo "   docker-compose -f docker-compose.sidecar-local.yml up -d"
  exit 0
fi

# Cloud Run environment
if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
  REGION="us-central1"
else
  PROJECT_ID="labs-stg"
  REGION="us-central1"
fi

SERVICE_NAME="traefik-${ENVIRONMENT}"

echo "🌐 Traefik Gateway (${ENVIRONMENT})"
echo "===================================="
echo ""

# Get main Traefik service URL
echo "🔍 Getting Traefik gateway URL..."
MAIN_URL=$(gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)" 2>/dev/null || echo "")

if [ -z "${MAIN_URL}" ]; then
  echo "❌ Traefik gateway not found!"
  echo ""
  echo "   Service name: ${SERVICE_NAME}"
  echo "   Project: ${PROJECT_ID}"
  echo "   Region: ${REGION}"
  echo ""
  echo "💡 Deploy the gateway first:"
  echo "   ./deploy-sidecar.sh ${ENVIRONMENT}"
  exit 1
fi

echo "✅ Traefik Gateway URL:"
echo "   ${MAIN_URL}"
echo ""

# Get dashboard URL
DASHBOARD_URL=$(gcloud run services describe "traefik-dashboard-${ENVIRONMENT}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)" 2>/dev/null || echo "")

if [ -n "${DASHBOARD_URL}" ]; then
  echo "📊 Dashboard URL:"
  echo "   ${DASHBOARD_URL}/dashboard/"
  echo ""
fi

# Get service status
echo "📋 Service Status:"
STATUS=$(gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.conditions[0].status)" 2>/dev/null || echo "Unknown")

if [ "${STATUS}" = "True" ]; then
  echo "   ✅ Service is Ready"
else
  echo "   ⚠️  Service status: ${STATUS}"
fi

echo ""
echo "🧪 Test the gateway:"
echo "   curl ${MAIN_URL}/ping"
echo ""
echo "   # With authentication:"
echo "   TOKEN=\$(gcloud auth print-identity-token)"
echo "   curl -H \"Authorization: Bearer \${TOKEN}\" ${MAIN_URL}/"
echo ""
