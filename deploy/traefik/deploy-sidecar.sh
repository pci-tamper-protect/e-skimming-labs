#!/bin/bash
# Deploy Traefik to Cloud Run with Sidecar Architecture
# Usage: ./deploy/traefik/deploy-sidecar.sh [stg|prd]
#        (Can be run from repo root or from deploy/traefik directory)
#
# This script:
# 1. Builds and pushes Docker images for all sidecars
# 2. Deploys Traefik to Cloud Run with sidecars using YAML configuration
# 3. Sets up IAM bindings
#
# Sidecar Architecture:
# - Main Traefik container: serves web traffic on port 8080
# - Provider sidecar: generates routes.yml into shared volume
# - Dashboard sidecar: serves dashboard UI (separate service)
#
# Version: Uses Traefik v2.10 by default (stable)
# For Traefik v3.0, use Dockerfile.cloudrun.sidecar.traefik-3.0 and
# Dockerfile.dashboard-sidecar.traefik-3.0

set -e

# Find script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source credential check
source "$DEPLOY_DIR/check-credentials.sh"

# Check credentials before proceeding
if ! check_credentials; then
  echo ""
  echo "❌ Deployment aborted: Please fix credential issues first"
  exit 1
fi
echo ""

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
  DOMAIN="labs.pcioasis.com"
else
  PROJECT_ID="labs-stg"
  DOMAIN="labs.stg.pcioasis.com"
fi

HOME_PROJECT_ID="labs-home-${ENVIRONMENT}"
SERVICE_NAME="traefik-${ENVIRONMENT}"
SERVICE_ACCOUNT="traefik-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🚀 Deploying Traefik with Sidecar Architecture to ${ENVIRONMENT}..."
echo "   Project: ${PROJECT_ID}"
echo "   Service: ${SERVICE_NAME}"
echo ""

# Check for and clear service account impersonation (deploy should use user credentials)
CURRENT_IMPERSONATE=$(gcloud config get-value auth/impersonate_service_account 2>/dev/null || echo "")
if [ -n "${CURRENT_IMPERSONATE}" ]; then
  echo "⚠️  WARNING: Service account impersonation is configured: ${CURRENT_IMPERSONATE}"
  echo "   Clearing impersonation to use your user credentials..."
  gcloud config unset auth/impersonate_service_account --quiet
  echo "   ✅ Impersonation cleared"
fi

# Verify user is authenticated (not using service account)
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
if [ -z "${CURRENT_USER}" ]; then
  echo "❌ No active gcloud authentication found"
  echo "   Please run: gcloud auth login"
  exit 1
fi

echo "👤 Using credentials for: ${CURRENT_USER}"
echo ""

# Authenticate Docker to Artifact Registry
echo "🔐 Authenticating Docker to Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# Build and push images
echo "📦 Building and pushing Docker images..."

# Find script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repo root is e-skimming-labs (parent of deploy)
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# traefik-cloudrun-provider is a sibling of e-skimming-labs
PROVIDER_DIR="${REPO_ROOT}/../traefik-cloudrun-provider"
TRAEFIK_DEPLOY_DIR="${REPO_ROOT}/deploy/traefik"

# Verify directories exist
if [ ! -d "${TRAEFIK_DEPLOY_DIR}" ]; then
  echo "❌ ERROR: Traefik deploy directory not found: ${TRAEFIK_DEPLOY_DIR}"
  exit 1
fi

if [ ! -d "${PROVIDER_DIR}" ]; then
  echo "❌ ERROR: traefik-cloudrun-provider directory not found: ${PROVIDER_DIR}"
  echo "   Make sure traefik-cloudrun-provider is a sibling directory of e-skimming-labs"
  exit 1
fi

# Build main Traefik image
echo "   Building main Traefik image..."
cd "${TRAEFIK_DEPLOY_DIR}"
docker build -f Dockerfile.cloudrun.sidecar -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik:latest" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik:latest"

# Build provider sidecar image
echo "   Building provider sidecar image..."
cd "${PROVIDER_DIR}"
docker build -f Dockerfile.provider.sidecar -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-cloudrun-provider:latest" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-cloudrun-provider:latest"

# Build dashboard sidecar image
echo "   Building dashboard sidecar image..."
cd "${TRAEFIK_DEPLOY_DIR}"
docker build -f Dockerfile.dashboard-sidecar -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-dashboard:latest" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-dashboard:latest"

echo "✅ All images built and pushed"
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

# Get home-index URL so Traefik entrypoint can write ForwardAuth middlewares (lab routes require login)
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
if [ -n "${HOME_INDEX_URL}" ]; then
  echo "✅ HOME_INDEX_URL set for lab auth: ${HOME_INDEX_URL}"
else
  echo "⚠️  Could not get home-index URL; lab routes may not require login. Run: ./deploy/traefik/set-home-index-url.sh ${ENVIRONMENT}"
fi
echo ""

# Generate Cloud Run YAML with environment-specific values (use | for URL sed delimiter to avoid escaping slashes)
TEMP_YAML=$(mktemp)
sed "s/labs-stg/${PROJECT_ID}/g; s/labs-home-stg/${HOME_PROJECT_ID}/g; s/stg/${ENVIRONMENT}/g; s|__HOME_INDEX_URL__|${HOME_INDEX_URL}|g" \
    "${TRAEFIK_DEPLOY_DIR}/cloudrun-sidecar.yaml" > "${TEMP_YAML}"

# Deploy main Traefik service with provider sidecar
echo "🚀 Deploying main Traefik service with provider sidecar..."
gcloud run services replace "${TEMP_YAML}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}"

rm "${TEMP_YAML}"

if [ -z "${HOME_INDEX_URL}" ]; then
  HOME_INDEX_URL=$(gcloud run services describe "home-index-${ENVIRONMENT}" \
    --region="${REGION}" --project="${HOME_PROJECT_ID}" --format='value(status.url)' 2>/dev/null || echo "")
fi
if [ -n "${HOME_INDEX_URL}" ]; then
  echo "🔐 Setting HOME_INDEX_URL on Traefik service (lab auth)..."
  gcloud run services update "${SERVICE_NAME}" \
    --region="${REGION}" --project="${PROJECT_ID}" \
    --set-env-vars "HOME_INDEX_URL=${HOME_INDEX_URL}" --quiet
fi

# Get the actual service URL after deployment (needed for dashboard service)
echo "🔍 Getting main Traefik service URL..."
MAIN_TRAEFIK_URL=$(gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)")

echo ""
echo "✅ Main Traefik service deployed successfully!"
echo "   Service URL: ${MAIN_TRAEFIK_URL}"
echo ""

# Deploy dashboard service (separate service)
echo "🚀 Deploying dashboard service..."
DASHBOARD_SERVICE_NAME="traefik-dashboard-${ENVIRONMENT}"
DASHBOARD_TEMP_YAML=$(mktemp)

# Generate dashboard YAML with main Traefik URL
sed "s/labs-stg/${PROJECT_ID}/g; s/labs-home-stg/${HOME_PROJECT_ID}/g; s/stg/${ENVIRONMENT}/g; s|<PROJECT_NUMBER>|${MAIN_TRAEFIK_URL}|g" \
    "${TRAEFIK_DEPLOY_DIR}/traefik-dashboard-sidecar.yaml" > "${DASHBOARD_TEMP_YAML}"

gcloud run services replace "${DASHBOARD_TEMP_YAML}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}"

rm "${DASHBOARD_TEMP_YAML}"

DASHBOARD_URL=$(gcloud run services describe "${DASHBOARD_SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)")

echo ""
echo "✅ Dashboard service deployed successfully!"
echo "   Dashboard URL: ${DASHBOARD_URL}"
echo ""
echo "💡 Next steps:"
echo "   1. Verify IAM bindings are correct (Terraform manages these)"
echo "   2. If this is production, set up domain mapping:"
echo "      gcloud run domain-mappings create --service=${SERVICE_NAME} --domain=${DOMAIN} --region=${REGION} --project=${PROJECT_ID}"
echo "   3. Test main service: curl ${MAIN_TRAEFIK_URL}/ping"
echo "   4. Test dashboard: curl ${DASHBOARD_URL}/dashboard/"
