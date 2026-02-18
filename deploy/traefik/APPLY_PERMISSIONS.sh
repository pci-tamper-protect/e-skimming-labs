#!/bin/bash
# Apply run.viewer permissions to Traefik and Labs deploy service accounts
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
LABS_DEPLOY_SA="labs-deploy-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🔐 Applying run.viewer permissions"
echo "   Environment: ${ENVIRONMENT}"
echo ""

# --- Traefik SA (runtime) ---
echo "1️⃣  Traefik SA: ${TRAEFIK_SA}"
echo "   Granting roles/run.viewer on labs project..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${TRAEFIK_SA}" \
  --role="roles/run.viewer" \
  --condition=None

echo "   Granting roles/run.viewer on home project..."
gcloud projects add-iam-policy-binding "${HOME_PROJECT_ID}" \
  --member="serviceAccount:${TRAEFIK_SA}" \
  --role="roles/run.viewer" \
  --condition=None

echo "   ✅ Traefik SA permissions applied"
echo ""

# --- Labs deploy SA (CI/CD) ---
# Needed so deploy workflow can run: gcloud run services describe home-index-stg --project=labs-home-stg
echo "2️⃣  Labs deploy SA: ${LABS_DEPLOY_SA}"
echo "   Granting roles/run.viewer on home project (for HOME_INDEX_URL fetch)..."
gcloud projects add-iam-policy-binding "${HOME_PROJECT_ID}" \
  --member="serviceAccount:${LABS_DEPLOY_SA}" \
  --role="roles/run.viewer" \
  --condition=None

echo "   ✅ Labs deploy SA can describe home-index services"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Permissions applied successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Redeploy Traefik to pick up the new permissions"
echo "  2. Check logs to verify route generation is working"
echo "  3. Run: ./deploy/traefik/check-routes.sh ${ENVIRONMENT}"
echo ""



