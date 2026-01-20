#!/bin/bash
# Apply run.viewer permissions to Traefik service account
# Run this script to grant permissions immediately (in addition to Terraform)

set -e

ENVIRONMENT="${1:-stg}"

if [ -z "$ENVIRONMENT" ]; then
  echo "Usage: $0 [stg|prd]"
  exit 1
fi

PROJECT_ID="labs-${ENVIRONMENT}"
HOME_PROJECT_ID="labs-home-${ENVIRONMENT}"
TRAEFIK_SA="traefik-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🔐 Applying run.viewer permissions to Traefik service account"
echo "   Environment: ${ENVIRONMENT}"
echo "   Traefik SA: ${TRAEFIK_SA}"
echo ""

# Apply to labs project
echo "1️⃣  Granting roles/run.viewer on labs project..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${TRAEFIK_SA}" \
  --role="roles/run.viewer" \
  --condition=None

echo "   ✅ Granted roles/run.viewer on ${PROJECT_ID}"
echo ""

# Apply to home project
echo "2️⃣  Granting roles/run.viewer on home project..."
gcloud projects add-iam-policy-binding "${HOME_PROJECT_ID}" \
  --member="serviceAccount:${TRAEFIK_SA}" \
  --role="roles/run.viewer" \
  --condition=None

echo "   ✅ Granted roles/run.viewer on ${HOME_PROJECT_ID}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Permissions applied successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Redeploy Traefik to pick up the new permissions"
echo "  2. Check logs to verify route generation is working"
echo "  3. Run: ./deploy/traefik/debug/check-stg-middleware-actual.sh ${ENVIRONMENT}"
echo ""



