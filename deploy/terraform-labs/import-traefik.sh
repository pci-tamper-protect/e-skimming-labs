#!/bin/bash
# Import existing Traefik service into Terraform state
# Usage: ./import-traefik.sh [stg|prd]

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

echo "📥 Importing Traefik service into Terraform state..."
echo "   Environment: ${ENVIRONMENT}"
echo "   Project: ${PROJECT_ID}"
echo "   Service: ${SERVICE_NAME}"
echo "   Resource: ${RESOURCE_ADDRESS}"
echo "   Resource ID: ${RESOURCE_ID}"
echo ""

# Check if service exists
echo "🔍 Checking if service exists..."
if ! gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(name)" > /dev/null 2>&1; then
  echo "❌ Service ${SERVICE_NAME} does not exist in ${PROJECT_ID}"
  echo "   Cannot import. Please create the service first or build the Docker image."
  exit 1
fi

echo "✅ Service exists. Importing into Terraform state..."
terraform import \
  -var="environment=${ENVIRONMENT}" \
  "${RESOURCE_ADDRESS}" \
  "${RESOURCE_ID}"

echo ""
echo "✅ Import complete!"
echo ""
echo "Next steps:"
echo "  1. Run: terraform plan -var=\"environment=${ENVIRONMENT}\""
echo "  2. Review the plan to see what changes Terraform wants to make"
echo "  3. Run: terraform apply -var=\"environment=${ENVIRONMENT}\""
