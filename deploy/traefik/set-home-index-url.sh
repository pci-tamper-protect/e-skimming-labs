#!/usr/bin/env bash
# Set HOME_INDEX_URL on the Traefik Cloud Run service so lab routes require login.
# Use this when the sidecar deploy didn't get the URL (e.g. wrong project or permissions)
# or to fix auth without a full redeploy.
#
# Usage: ./deploy/traefik/set-home-index-url.sh [stg|prd]
# From repo root or from deploy/traefik.

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
  HOME_PROJECT_ID="labs-home-prd"
else
  PROJECT_ID="labs-stg"
  HOME_PROJECT_ID="labs-home-stg"
fi

SERVICE_NAME="traefik-${ENVIRONMENT}"

echo "Resolving home-index URL from project ${HOME_PROJECT_ID}..."
HOME_INDEX_URL=$(gcloud run services describe "home-index-${ENVIRONMENT}" \
  --region="${REGION}" \
  --project="${HOME_PROJECT_ID}" \
  --format='value(status.url)' 2>/dev/null || echo "")

if [ -z "${HOME_INDEX_URL}" ]; then
  HOME_INDEX_URL=$(gcloud run services describe "home-index" \
    --region="${REGION}" \
    --project="${HOME_PROJECT_ID}" \
    --format='value(status.url)' 2>/dev/null || echo "")
fi

if [ -z "${HOME_INDEX_URL}" ]; then
  echo "❌ Could not get home-index URL. Ensure:"
  echo "   1. You have access to project ${HOME_PROJECT_ID}"
  echo "   2. Service home-index-${ENVIRONMENT} (or home-index) exists in that project"
  echo "   Run: gcloud run services list --project=${HOME_PROJECT_ID} --region=${REGION}"
  exit 1
fi

echo "✅ HOME_INDEX_URL=${HOME_INDEX_URL}"
echo "Updating ${SERVICE_NAME} to set HOME_INDEX_URL (will create a new revision)..."
gcloud run services update "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --set-env-vars "HOME_INDEX_URL=${HOME_INDEX_URL}"

echo ""
echo "✅ Done. New instances will write auth-forward.yml and lab routes will require login."
echo "   Existing instances may need to scale down before new ones pick up the env."
