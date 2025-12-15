#!/bin/bash
# Import existing Cloud Run services into Terraform state
# This resolves conflicts when services are created by GitHub Actions workflow

set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-stg}"
PROJECT_ID="labs-home-${ENVIRONMENT}"
REGION="us-central1"

echo "📥 Importing existing Cloud Run services into Terraform state"
echo "   Environment: $ENVIRONMENT"
echo "   Project: $PROJECT_ID"
echo "   Region: $REGION"
echo ""

cd "$(dirname "$0")"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
  echo "🏗️  Initializing Terraform..."
  terraform init -backend-config="backend-${ENVIRONMENT}.conf"
fi

# Import SEO service
SERVICE_NAME="home-seo-${ENVIRONMENT}"
if gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" &>/dev/null; then
  echo "📥 Importing $SERVICE_NAME..."
  terraform import \
    -var="environment=${ENVIRONMENT}" \
    -var="deploy_services=true" \
    "google_cloud_run_v2_service.home_seo_service[0]" \
    "projects/${PROJECT_ID}/locations/${REGION}/services/${SERVICE_NAME}" || {
    echo "   ⚠️  Failed to import (may already be in state)"
  }
else
  echo "   ⚠️  Service $SERVICE_NAME does not exist, skipping import"
fi

# Import Index service
SERVICE_NAME="home-index-${ENVIRONMENT}"
if gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" &>/dev/null; then
  echo "📥 Importing $SERVICE_NAME..."
  terraform import \
    -var="environment=${ENVIRONMENT}" \
    -var="deploy_services=true" \
    "google_cloud_run_v2_service.home_index_service[0]" \
    "projects/${PROJECT_ID}/locations/${REGION}/services/${SERVICE_NAME}" || {
    echo "   ⚠️  Failed to import (may already be in state)"
  }
else
  echo "   ⚠️  Service $SERVICE_NAME does not exist, skipping import"
fi

echo ""
echo "✅ Import complete!"
echo ""
echo "💡 Next steps:"
echo "   1. Review the Terraform state: terraform state list"
echo "   2. Plan to see what Terraform wants to change:"
echo "      terraform plan -var=\"environment=${ENVIRONMENT}\" -var=\"deploy_services=true\""
echo "   3. If the plan looks good, apply:"
echo "      terraform apply -var=\"environment=${ENVIRONMENT}\" -var=\"deploy_services=true\""
echo ""
echo "⚠️  Note: After importing, you should either:"
echo "   - Let Terraform manage services (remove gcloud run deploy from workflow)"
echo "   - OR let workflow manage services (remove service resources from Terraform)"
echo "   Mixing both will cause conflicts!"

