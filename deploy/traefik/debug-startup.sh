#!/bin/bash
# Debug Traefik Cloud Run startup failures
# Usage: ./debug-startup.sh [stg|prd]

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
else
  PROJECT_ID="labs-stg"
fi

SERVICE_NAME="traefik-${ENVIRONMENT}"

echo "🔍 Debugging Traefik Startup Failure"
echo "   Service: ${SERVICE_NAME}"
echo "   Project: ${PROJECT_ID}"
echo ""

# Get latest revision
REVISION=$(gcloud run revisions list \
  --service="${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --limit=1 \
  --format="value(name)" 2>/dev/null | head -1)

if [ -z "${REVISION}" ]; then
  echo "❌ No revisions found"
  exit 1
fi

echo "📊 Revision Status:"
gcloud run revisions describe "${REVISION}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(status.conditions)"

echo ""
echo "📋 Main Traefik Container Logs (last 100 lines):"
gcloud run services logs read "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --container=traefik \
  --limit=100

echo ""
echo "📋 Provider Sidecar Logs (last 50 lines):"
gcloud run services logs read "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --container=provider \
  --limit=50

echo ""
echo "🔍 Checking for port conflicts..."
echo "   (If port 8080 is in use, this could cause 'address already in use' error)"

echo ""
echo "💡 Common Issues:"
echo "   - 'address already in use': Only one container can bind to port 8080"
echo "   - 'entryPoint traefik' error: Check for conflicting entrypoint definitions"
echo "   - Traefik not starting: Check config file errors in logs above"
echo "   - /ping endpoint not responding: Check port 8080 is listening"
echo "   - Shared volume issues: Check volume mounts"
echo "   - Provider not generating routes: Check IAM permissions"
echo ""
echo "🔧 To fix 'address already in use':"
echo "   1. Ensure only the main Traefik container has containerPort: 8080"
echo "   2. Verify no other process is binding to port 8080"
echo "   3. Check that entrypoint 'web' is correctly defined in traefik.yml"
