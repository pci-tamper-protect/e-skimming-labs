#!/bin/bash
# Rebuild all Traefik sidecar images with --no-cache
# Usage: ./deploy/traefik/rebuild-images.sh [stg|prd]

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
else
  PROJECT_ID="labs-stg"
fi

echo "🔨 Rebuilding all Traefik sidecar images (--no-cache)..."
echo "   Environment: ${ENVIRONMENT}"
echo "   Project: ${PROJECT_ID}"
echo ""

# Authenticate Docker to Artifact Registry
echo "🔐 Authenticating Docker to Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# Find directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
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

# Build main Traefik image (v3.0)
echo "📦 Building main Traefik image (--no-cache, Traefik v3.0)..."
cd "${TRAEFIK_DEPLOY_DIR}"
docker build --no-cache -f Dockerfile.cloudrun.sidecar.traefik-3.0 -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik:latest" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik:latest"
echo "✅ Main Traefik image built and pushed"
echo ""

# Build provider sidecar image
echo "📦 Building provider sidecar image (--no-cache)..."
cd "${PROVIDER_DIR}"
docker build --no-cache -f Dockerfile.provider.sidecar -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-cloudrun-provider:latest" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-cloudrun-provider:latest"
echo "✅ Provider sidecar image built and pushed"
echo ""

# Build dashboard sidecar image
echo "📦 Building dashboard sidecar image (--no-cache, Traefik v3.0)..."
cd "${TRAEFIK_DEPLOY_DIR}"
docker build --no-cache -f Dockerfile.dashboard-sidecar.traefik-3.0 -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-dashboard:latest" .
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik-dashboard:latest"
echo "✅ Dashboard sidecar image built and pushed"
echo ""

echo "🎉 All images rebuilt and pushed!"
echo ""
echo "💡 Next step: Deploy to Cloud Run"
echo "   ./deploy/traefik/deploy-sidecar.sh ${ENVIRONMENT}"
