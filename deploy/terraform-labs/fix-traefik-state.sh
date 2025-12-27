#!/bin/bash
# Fix Traefik service state - import if exists, or handle deletion protection
# Usage: ./fix-traefik-state.sh [stg|prd]

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
else
  PROJECT_ID="labs-stg"
fi

SERVICE_NAME="traefik-${ENVIRONMENT}"
RESOURCE_ADDRESS="google_cloud_run_v2_service.traefik[0]"
RESOURCE_ID="projects/${PROJECT_ID}/locations/${REGION}/services/${SERVICE_NAME}"

echo "🔍 Checking Traefik service state..."
echo "   Environment: ${ENVIRONMENT}"
echo "   Project: ${PROJECT_ID}"
echo "   Service: ${SERVICE_NAME}"
echo ""

# Check if service exists in GCP
echo "1️⃣  Checking if service exists in GCP..."
if gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(name)" > /dev/null 2>&1; then
  echo "   ✅ Service exists in GCP"
  SERVICE_EXISTS=true
else
  echo "   ❌ Service does not exist in GCP"
  SERVICE_EXISTS=false
fi

# Check if service exists in Terraform state
echo ""
echo "2️⃣  Checking if service exists in Terraform state..."
if terraform state show "${RESOURCE_ADDRESS}" > /dev/null 2>&1; then
  echo "   ✅ Service exists in Terraform state"
  IN_STATE=true
else
  echo "   ❌ Service does not exist in Terraform state"
  IN_STATE=false
fi

echo ""
echo "📋 Current state:"
echo "   GCP: ${SERVICE_EXISTS}"
echo "   Terraform: ${IN_STATE}"
echo ""

# Determine action
if [ "$SERVICE_EXISTS" = true ] && [ "$IN_STATE" = false ]; then
  echo "✅ Solution: Import existing service into Terraform state"
  echo ""
  echo "Running: terraform import ${RESOURCE_ADDRESS} ${RESOURCE_ID}"
  terraform import \
    -var="environment=${ENVIRONMENT}" \
    "${RESOURCE_ADDRESS}" \
    "${RESOURCE_ID}"

  echo ""
  echo "✅ Import complete! Now run: terraform plan -var=\"environment=${ENVIRONMENT}\""

elif [ "$SERVICE_EXISTS" = false ] && [ "$IN_STATE" = true ]; then
  echo "⚠️  Service exists in Terraform state but not in GCP"
  echo "   This means Terraform thinks it should exist but it was deleted"
  echo ""
  echo "Solution: Remove from state, then let Terraform create it"
  echo "   terraform state rm ${RESOURCE_ADDRESS}"
  echo "   terraform apply -var=\"environment=${ENVIRONMENT}\""

elif [ "$SERVICE_EXISTS" = true ] && [ "$IN_STATE" = true ]; then
  echo "✅ Service exists in both GCP and Terraform state"
  echo "   The issue might be that Terraform wants to replace it"
  echo ""
  echo "Run: terraform plan -var=\"environment=${ENVIRONMENT}\""
  echo "   Look for lines that say 'forces replacement' or 'must be replaced'"
  echo "   With ignore_changes = all, Terraform shouldn't try to replace it"

elif [ "$SERVICE_EXISTS" = false ] && [ "$IN_STATE" = false ]; then
  echo "✅ Service doesn't exist - Terraform will create it"
  echo "   But first, make sure the Docker image exists:"
  echo "   cd ../traefik && ./build-and-push.sh ${ENVIRONMENT}"
  echo "   Then run: terraform apply -var=\"environment=${ENVIRONMENT}\""
fi
