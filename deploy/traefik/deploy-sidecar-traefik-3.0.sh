#!/bin/bash
# Deploy Traefik 3.0 to Cloud Run with Sidecar Architecture
# Usage: ./deploy/traefik/deploy-sidecar-traefik-3.0.sh [stg|prd]
#        (Can be run from repo root or from deploy/traefik directory)
#
# This script:
# 1. Builds and pushes Docker images for all sidecars (using Traefik v3.0)
# 2. Deploys Traefik to Cloud Run with sidecars using YAML configuration
# 3. Sets up IAM bindings
#
# Sidecar Architecture:
# - Main Traefik container: serves web traffic on port 8080 (Traefik v3.0)
# - Provider sidecar: generates routes.yml into shared volume
# - Dashboard sidecar: serves dashboard UI (separate service, Traefik v3.0)
#
# Version: Uses Traefik v3.0 (latest features)
# For Traefik v2.10 (stable), use deploy-sidecar.sh

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

echo "🚀 Deploying Traefik 3.0 with Sidecar Architecture to ${ENVIRONMENT}..."
echo "   Project: ${PROJECT_ID}"
echo "   Service: ${SERVICE_NAME}"
echo "   Traefik Version: v3.0"
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
echo "📦 Building and pushing Docker images (Traefik v3.0)..."

# Find script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repo root is e-skimming-labs (parent of deploy)
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TRAEFIK_DEPLOY_DIR="${REPO_ROOT}/deploy/traefik"
PROVIDER_GITHUB="git@github.com:pci-tamper-protect/traefik-cloudrun-provider.git"
PROVIDER_CLONE_DIR="${TRAEFIK_DEPLOY_DIR}/.traefik-cloudrun-provider-clone"

# Verify directories exist
if [ ! -d "${TRAEFIK_DEPLOY_DIR}" ]; then
  echo "❌ ERROR: Traefik deploy directory not found: ${TRAEFIK_DEPLOY_DIR}"
  exit 1
fi

# Resolve provider source directory (in priority order):
#   1. deploy/traefik/src/github.com/pci-tamper-protect/traefik-cloudrun-provider
#      (standard Traefik localPlugins path — symlink or dir, create with:
#      ln -s ../../../traefik-cloudrun-provider deploy/traefik/src/github.com/pci-tamper-protect/traefik-cloudrun-provider)
#   2. ../traefik-cloudrun-provider (sibling repo, local dev default)
#   3. Clone from GitHub into a temporary directory (CI/CD fallback)
PROVIDER_DIR=""
if [ -d "${TRAEFIK_DEPLOY_DIR}/src/github.com/pci-tamper-protect/traefik-cloudrun-provider" ]; then
  PROVIDER_DIR="${TRAEFIK_DEPLOY_DIR}/src/github.com/pci-tamper-protect/traefik-cloudrun-provider"
  echo "   Using provider from localPlugins path: ${PROVIDER_DIR}"
elif [ -d "${REPO_ROOT}/../traefik-cloudrun-provider" ]; then
  PROVIDER_DIR="${REPO_ROOT}/../traefik-cloudrun-provider"
  echo "   Using provider from sibling repo: ${PROVIDER_DIR}"
else
  echo "   Provider not found locally — cloning from GitHub..."
  rm -rf "${PROVIDER_CLONE_DIR}"
  git clone --depth=1 "${PROVIDER_GITHUB}" "${PROVIDER_CLONE_DIR}"
  PROVIDER_DIR="${PROVIDER_CLONE_DIR}"
  echo "   Using provider from GitHub clone: ${PROVIDER_DIR}"
fi

# Build main Traefik 3.0 image
echo "   Building main Traefik 3.0 image..."
cd "${TRAEFIK_DEPLOY_DIR}"
docker build -f Dockerfile.cloudrun.sidecar.traefik-3.0 -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik:v3.0" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik:v3.0"

# Build provider sidecar image (same for v2.10 and v3.0)
echo "   Building provider sidecar image..."
cd "${PROVIDER_DIR}"
docker build -f Dockerfile.provider.sidecar -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-cloudrun-provider:latest" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-cloudrun-provider:latest"

# Build dashboard sidecar image (Traefik 3.0 version)
echo "   Building dashboard sidecar image (Traefik 3.0)..."
cd "${TRAEFIK_DEPLOY_DIR}"
docker build -f Dockerfile.dashboard-sidecar.traefik-3.0 -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-dashboard:v3.0" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-dashboard:v3.0"

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
# Must query the HOME project (labs-home-stg); ensure gcloud can access it.
HOME_INDEX_URL=$(gcloud run services describe "home-index-${ENVIRONMENT}" \
  --region="${REGION}" \
  --project="${HOME_PROJECT_ID}" \
  --format='value(status.url)' 2>/dev/null || echo "")
if [ -z "${HOME_INDEX_URL}" ]; then
  # Fallback: try service name without env suffix (some deploys use "home-index" only)
  HOME_INDEX_URL=$(gcloud run services describe "home-index" \
    --region="${REGION}" \
    --project="${HOME_PROJECT_ID}" \
    --format='value(status.url)' 2>/dev/null || echo "")
fi
if [ -n "${HOME_INDEX_URL}" ]; then
  echo "✅ HOME_INDEX_URL set for lab auth: ${HOME_INDEX_URL}"
else
  echo "⚠️  Could not get home-index URL (project=${HOME_PROJECT_ID}, region=${REGION})"
  echo "   Lab routes will NOT require login until HOME_INDEX_URL is set."
  echo "   After deploy, run: ./deploy/traefik/set-home-index-url.sh ${ENVIRONMENT}"
fi
echo ""

# Generate Cloud Run YAML with environment-specific values and v3.0 image tags (use | for URL sed delimiter)
TEMP_YAML=$(mktemp)
sed "s/labs-stg/${PROJECT_ID}/g; \
     s/labs-home-stg/${HOME_PROJECT_ID}/g; \
     s/stg/${ENVIRONMENT}/g; \
     s|__HOME_INDEX_URL__|${HOME_INDEX_URL}|g; \
     s|traefik:latest|traefik:v3.0|g" \
    "${TRAEFIK_DEPLOY_DIR}/cloudrun-sidecar.yaml" > "${TEMP_YAML}"

# Deploy main Traefik service with provider sidecar
echo "🚀 Deploying main Traefik 3.0 service with provider sidecar..."
gcloud run services replace "${TEMP_YAML}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}"

rm "${TEMP_YAML}"

# If we didn't have HOME_INDEX_URL before, retry once (e.g. project permissions)
if [ -z "${HOME_INDEX_URL}" ]; then
  HOME_INDEX_URL=$(gcloud run services describe "home-index-${ENVIRONMENT}" \
    --region="${REGION}" \
    --project="${HOME_PROJECT_ID}" \
    --format='value(status.url)' 2>/dev/null || echo "")
fi
# Ensure Traefik service has HOME_INDEX_URL so entrypoint writes auth-forward.yml (lab routes require login)
if [ -n "${HOME_INDEX_URL}" ]; then
  echo "🔐 Setting HOME_INDEX_URL on Traefik service (lab auth)..."
  gcloud run services update "${SERVICE_NAME}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    --update-env-vars "HOME_INDEX_URL=${HOME_INDEX_URL}" \
    --quiet
fi

# PRD: Make Traefik public so labs.pcioasis.com is accessible (backend services stay private, accessed via Traefik)
if [ "${ENVIRONMENT}" = "prd" ]; then
  echo "🌐 Making Traefik public (labs.pcioasis.com)..."
  gcloud run services add-iam-policy-binding "${SERVICE_NAME}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --quiet
  echo "   ✅ Traefik is now publicly accessible"
fi

# Get the actual service URL after deployment (needed for dashboard service)
echo "🔍 Getting main Traefik service URL..."
MAIN_TRAEFIK_URL=$(gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)")

echo ""
echo "✅ Main Traefik 3.0 service deployed successfully!"
echo "   Service URL: ${MAIN_TRAEFIK_URL}"
echo ""

# Deploy dashboard service (separate service)
echo "🚀 Deploying dashboard service (Traefik 3.0)..."
DASHBOARD_SERVICE_NAME="traefik-dashboard-${ENVIRONMENT}"
DASHBOARD_TEMP_YAML=$(mktemp)

# Generate dashboard YAML with main Traefik URL and v3.0 image tag
sed "s/labs-stg/${PROJECT_ID}/g; \
     s/labs-home-stg/${HOME_PROJECT_ID}/g; \
     s/stg/${ENVIRONMENT}/g; \
     s|<PROJECT_NUMBER>|${MAIN_TRAEFIK_URL}|g; \
     s|traefik-dashboard:latest|traefik-dashboard:v3.0|g" \
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
echo "✅ Dashboard service (Traefik 3.0) deployed successfully!"
echo "   Dashboard URL: ${DASHBOARD_URL}"
echo ""
echo "🎉 Traefik 3.0 Sidecar Deployment Complete!"
echo ""
echo "📝 Deployment Summary:"
echo "   Traefik Version: v3.0"
echo "   Main Service: ${MAIN_TRAEFIK_URL}"
echo "   Dashboard: ${DASHBOARD_URL}"
echo ""
echo "💡 Next steps:"
echo "   1. Verify IAM bindings are correct (Terraform manages these)"
echo "   2. If this is production, set up domain mapping:"
echo "      gcloud run domain-mappings create --service=${SERVICE_NAME} --domain=${DOMAIN} --region=${REGION} --project=${PROJECT_ID}"
echo "   3. Test main service: curl ${MAIN_TRAEFIK_URL}/ping"
echo "   4. Test dashboard: curl ${DASHBOARD_URL}/dashboard/"
