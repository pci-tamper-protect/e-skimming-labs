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

# --- PRD: Make Traefik public (labs.pcioasis.com) ---
if [ "${ENVIRONMENT}" = "prd" ]; then
  echo "3️⃣  Traefik service: make public (labs.pcioasis.com)"
  gcloud run services add-iam-policy-binding "traefik-${ENVIRONMENT}" \
    --region=us-central1 \
    --project="${PROJECT_ID}" \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --quiet
  echo "   ✅ Traefik is now publicly accessible"
  echo ""

  echo "4️⃣  Home-index service: make public (required for forwardAuth /api/auth/check)"
  echo "   Traefik's forwardAuth does not add GCP identity tokens; home-index must allow unauthenticated."
  gcloud run services add-iam-policy-binding "home-index-${ENVIRONMENT}" \
    --region=us-central1 \
    --project="${HOME_PROJECT_ID}" \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --quiet
  echo "   ✅ Home-index is now publicly accessible (forwardAuth will work)"
  echo ""

  echo "5️⃣  Lab services: grant Traefik invoker (fixes 403 on /lab2, /lab3)"
  for svc in lab-01-basic-magecart lab-02-dom-skimming lab-03-extension-hijacking lab1-c2 lab2-c2 lab3-extension; do
    if gcloud run services describe "${svc}-${ENVIRONMENT}" --region=us-central1 --project="${PROJECT_ID}" &>/dev/null; then
      gcloud run services add-iam-policy-binding "${svc}-${ENVIRONMENT}" \
        --region=us-central1 --project="${PROJECT_ID}" \
        --member="serviceAccount:${TRAEFIK_SA}" \
        --role="roles/run.invoker" \
        --quiet 2>/dev/null || true
      echo "   ✅ ${svc}-${ENVIRONMENT}"
    fi
  done
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Permissions applied successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Redeploy Traefik to pick up the new permissions"
echo "  2. Check logs to verify route generation is working"
echo "  3. Run: ./deploy/traefik/check-routes.sh ${ENVIRONMENT}"
echo ""



