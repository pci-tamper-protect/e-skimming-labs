#!/bin/bash
# Deploy Traefik to Cloud Run
# Usage: ./deploy.sh [stg|prd]
#
# This script:
# 1. Builds and pushes the Docker image (if needed)
# 2. Deploys Traefik to Cloud Run with proper configuration
# 3. Sets up IAM bindings
#
# Note: Terraform manages IAM bindings, but this script handles the initial deployment

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
  DOMAIN="labs.pcioasis.com"
else
  PROJECT_ID="labs-stg"
  DOMAIN="labs.stg.pcioasis.com"
fi

IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik:latest"
SERVICE_NAME="traefik-${ENVIRONMENT}"
SERVICE_ACCOUNT="traefik-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🚀 Deploying Traefik to ${ENVIRONMENT}..."
echo "   Project: ${PROJECT_ID}"
echo "   Service: ${SERVICE_NAME}"
echo "   Image: ${IMAGE_NAME}"
echo ""

# Always build and push the image first
echo "📦 Building and pushing Docker image..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/build-and-push.sh" "${ENVIRONMENT}"
echo ""

# Get project numbers for constructing service URLs
LABS_PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
HOME_PROJECT_ID="labs-home-${ENVIRONMENT}"
HOME_PROJECT_NUMBER=$(gcloud projects describe "${HOME_PROJECT_ID}" --format="value(projectNumber)")

# Construct service URLs
HOME_INDEX_URL="https://home-index-${ENVIRONMENT}-${HOME_PROJECT_NUMBER}.us-central1.run.app"
SEO_URL="https://home-seo-${ENVIRONMENT}-${HOME_PROJECT_NUMBER}.us-central1.run.app"
ANALYTICS_URL="https://labs-analytics-${ENVIRONMENT}-${LABS_PROJECT_NUMBER}.us-central1.run.app"

# Lab service URLs (query actual service URLs from Cloud Run)
LAB1_URL=$(gcloud run services describe "lab-01-basic-magecart-${ENVIRONMENT}" --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)" 2>/dev/null || echo "")
LAB1_C2_URL=$(gcloud run services describe "lab1-c2-${ENVIRONMENT}" --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)" 2>/dev/null || echo "")
LAB2_URL=$(gcloud run services describe "lab-02-dom-skimming-${ENVIRONMENT}" --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)" 2>/dev/null || echo "")
LAB2_C2_URL=$(gcloud run services describe "lab2-c2-${ENVIRONMENT}" --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)" 2>/dev/null || echo "")
LAB3_URL=$(gcloud run services describe "lab-03-extension-hijacking-${ENVIRONMENT}" --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)" 2>/dev/null || echo "")
LAB3_EXTENSION_URL=$(gcloud run services describe "lab3-extension-${ENVIRONMENT}" --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)" 2>/dev/null || echo "")

echo "📋 Service URLs:"
echo "   HOME_INDEX_URL: ${HOME_INDEX_URL}"
echo "   SEO_URL: ${SEO_URL}"
echo "   ANALYTICS_URL: ${ANALYTICS_URL}"
echo "   LAB1_URL: ${LAB1_URL}"
echo "   LAB1_C2_URL: ${LAB1_C2_URL}"
echo "   LAB2_URL: ${LAB2_URL}"
echo "   LAB2_C2_URL: ${LAB2_C2_URL}"
echo "   LAB3_URL: ${LAB3_URL}"
echo "   LAB3_EXTENSION_URL: ${LAB3_EXTENSION_URL}"
echo ""

# Check if service account exists
if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
  echo "❌ Service account ${SERVICE_ACCOUNT} does not exist"
  echo "   Please run Terraform first to create the service account:"
  echo "   cd ../terraform-labs"
  echo "   terraform apply -var=\"environment=${ENVIRONMENT}\""
  exit 1
fi

echo "🔐 Service account found: ${SERVICE_ACCOUNT}"
echo ""

# Deploy to Cloud Run
echo "🚀 Deploying Traefik to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --image="${IMAGE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --service-account="${SERVICE_ACCOUNT}" \
  --platform=managed \
  --no-allow-unauthenticated \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=1 \
  --max-instances=$([ "$ENVIRONMENT" = "prd" ] && echo "10" || echo "3") \
  --set-env-vars="ENVIRONMENT=${ENVIRONMENT}" \
  --set-env-vars="DOMAIN=${DOMAIN}" \
  --set-env-vars="LABS_PROJECT_ID=${PROJECT_ID}" \
  --set-env-vars="HOME_PROJECT_ID=${HOME_PROJECT_ID}" \
  --set-env-vars="REGION=${REGION}" \
  --set-env-vars="HOME_INDEX_URL=${HOME_INDEX_URL}" \
  --set-env-vars="SEO_URL=${SEO_URL}" \
  --set-env-vars="ANALYTICS_URL=${ANALYTICS_URL}" \
  --set-env-vars="LAB1_URL=${LAB1_URL}" \
  --set-env-vars="LAB1_C2_URL=${LAB1_C2_URL}" \
  --set-env-vars="LAB2_URL=${LAB2_URL}" \
  --set-env-vars="LAB2_C2_URL=${LAB2_C2_URL}" \
  --set-env-vars="LAB3_URL=${LAB3_URL}" \
  --set-env-vars="LAB3_EXTENSION_URL=${LAB3_EXTENSION_URL}" \
  --timeout=300 \
  --concurrency=80 \
  --cpu-throttling \
  --labels="environment=${ENVIRONMENT},component=traefik,project=e-skimming-labs,service-type=router"

echo ""
echo "✅ Traefik deployed successfully!"
echo ""
echo "📋 Service URL:"
gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)"
echo ""
echo "💡 Next steps:"
echo "   1. Verify IAM bindings are correct (Terraform manages these)"
echo "   2. If this is production, set up domain mapping:"
echo "      gcloud run domain-mappings create --service=${SERVICE_NAME} --domain=${DOMAIN} --region=${REGION} --project=${PROJECT_ID}"
echo "   3. Test the service: curl $(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --format='value(status.url)')/ping"
