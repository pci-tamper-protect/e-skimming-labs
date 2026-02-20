#!/bin/bash
# Deploy Home Services to Cloud Run (gcloud only, no Terraform)
# This script builds, pushes, and deploys home services (SEO, Index)
# Usage: ./deploy/deploy-home.sh [stg|prd] [image-tag] [--force-rebuild]
#        If image-tag is not provided, uses current git SHA

set -e

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source credential check
source "$SCRIPT_DIR/check-credentials.sh"

# Check credentials before proceeding
if ! check_credentials; then
  echo ""
  echo "❌ Deployment aborted: Please fix credential issues first"
  exit 1
fi
echo ""

# Parse arguments
ENVIRONMENT=""
FORCE_REBUILD=false
IMAGE_TAG=""

for arg in "$@"; do
  if [ "$arg" = "--force-rebuild" ]; then
    FORCE_REBUILD=true
  elif [ "$arg" = "stg" ] || [ "$arg" = "prd" ]; then
    ENVIRONMENT="$arg"
  elif [ -z "$IMAGE_TAG" ] && [ "$arg" != "--force-rebuild" ]; then
    IMAGE_TAG="$arg"
  fi
done

# Require environment
if [ -z "$ENVIRONMENT" ]; then
  echo "❌ Environment required: stg or prd"
  echo "Usage: $0 [stg|prd] [image-tag] [--force-rebuild]"
  exit 1
fi

# Load environment variables
source "$SCRIPT_DIR/load-env.sh"

# Configuration based on environment
if [ "$ENVIRONMENT" = "stg" ]; then
  HOME_PROJECT_ID="${HOME_PROJECT_ID:-labs-home-stg}"
  DOMAIN_PREFIX="labs.stg.pcioasis.com"
else
  HOME_PROJECT_ID="${HOME_PROJECT_ID:-labs-home-prd}"
  DOMAIN_PREFIX="labs.pcioasis.com"
fi

HOME_GAR_LOCATION="${LABS_REGION:-us-central1}"
HOME_REPOSITORY="e-skimming-labs-home"
LABS_PROJECT_ID="${LABS_PROJECT_ID:-labs-${ENVIRONMENT}}"
DOTENVX_SECRET_NAME="DOTENVX_KEY_$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')"

# Get image tag
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"

echo "🏠 Deploying Home Services to Cloud Run..."
echo "   Environment: $ENVIRONMENT"
echo "   Project: $HOME_PROJECT_ID"
echo "   Region: $HOME_GAR_LOCATION"
echo "   Image tag: $IMAGE_TAG"
if [ "$FORCE_REBUILD" = true ]; then
  echo "   ⚠️  Force rebuild: enabled"
fi
echo ""

cd "$REPO_ROOT"

# Authenticate to Artifact Registry
echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker ${HOME_GAR_LOCATION}-docker.pkg.dev --quiet

# ============================================================================
# BUILD AND DEPLOY FUNCTIONS
# ============================================================================

build_and_push() {
  local service_name="$1"
  local build_dir="$2"
  local dockerfile="$3"
  local image="$4"
  local build_args="${5:-}"

  echo "📦 Building $service_name..."
  
  if [ "$FORCE_REBUILD" = true ] || ! docker image inspect "$image" &>/dev/null; then
    docker build \
      -f "$build_dir/$dockerfile" \
      -t "$image" \
      $build_args \
      "$build_dir"
    
    echo "📤 Pushing $image..."
    docker push "$image"
  else
    echo "   ⏭️  Image exists, skipping build (use --force-rebuild to override)"
  fi
}

# ============================================================================
# DEPLOY HOME SERVICES
# ============================================================================

# 1. Deploy SEO Service
echo ""
echo "1️⃣  Deploying home-seo-${ENVIRONMENT}..."
SEO_IMAGE="${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:${IMAGE_TAG}"

build_and_push \
  "home-seo-${ENVIRONMENT}" \
  "deploy/shared-components/seo-service" \
  "Dockerfile" \
  "$SEO_IMAGE" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

gcloud run deploy home-seo-${ENVIRONMENT} \
  --image="$SEO_IMAGE" \
  --region=${HOME_GAR_LOCATION} \
  --platform=managed \
  --project=${HOME_PROJECT_ID} \
  --no-allow-unauthenticated \
  --service-account=home-runtime-sa@${HOME_PROJECT_ID}.iam.gserviceaccount.com \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=5 \
  --set-env-vars="PROJECT_ID=${HOME_PROJECT_ID},HOME_PROJECT_ID=${HOME_PROJECT_ID},ENVIRONMENT=${ENVIRONMENT},MAIN_DOMAIN=pcioasis.com,LABS_DOMAIN=${DOMAIN_PREFIX},LABS_PROJECT_ID=${LABS_PROJECT_ID}" \
  --update-secrets=/etc/secrets/dotenvx-key=${DOTENVX_SECRET_NAME}:latest \
  --labels="environment=${ENVIRONMENT},component=seo,project=e-skimming-labs-home,traefik_enable=true,traefik_http_routers_home-seo_rule_id=home-seo,traefik_http_routers_home-seo_priority=500,traefik_http_routers_home-seo_entrypoints=web,traefik_http_routers_home-seo_middlewares=strip-seo-prefix-file,traefik_http_services_home-seo_lb_port=8080"

echo "   ✅ SEO service deployed"

# 2. Deploy Index Service
echo ""
echo "2️⃣  Deploying home-index-${ENVIRONMENT}..."
INDEX_IMAGE="${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG}"

# Index service builds from repo root with Dockerfile in subdirectory
if [ "$FORCE_REBUILD" = true ] || ! docker image inspect "$INDEX_IMAGE" &>/dev/null; then
  docker build \
    -f "deploy/shared-components/home-index-service/Dockerfile" \
    -t "$INDEX_IMAGE" \
    --build-arg ENVIRONMENT=$ENVIRONMENT \
    .
  
  echo "📤 Pushing $INDEX_IMAGE..."
  docker push "$INDEX_IMAGE"
else
  echo "   ⏭️  Image exists, skipping build"
fi

# PRD: home-index must be public so Traefik's forwardAuth can call /api/auth/check without an identity token.
# Terraform (terraform-home/cloud-run.tf) also grants allUsers run.invoker on home-index for prd.
# STG: Keep private; Traefik SA has run.invoker via Terraform (terraform-home/iap.tf traefik_index_access).
HOME_INDEX_AUTH_FLAG="--no-allow-unauthenticated"
if [ "$ENVIRONMENT" = "prd" ]; then
  HOME_INDEX_AUTH_FLAG="--allow-unauthenticated"
fi

gcloud run deploy home-index-${ENVIRONMENT} \
  --image="$INDEX_IMAGE" \
  --region=${HOME_GAR_LOCATION} \
  --platform=managed \
  --project=${HOME_PROJECT_ID} \
  ${HOME_INDEX_AUTH_FLAG} \
  --service-account=fbase-adm-sdk-runtime@${HOME_PROJECT_ID}.iam.gserviceaccount.com \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=5 \
  --set-env-vars="HOME_PROJECT_ID=${HOME_PROJECT_ID},ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},LABS_DOMAIN=${DOMAIN_PREFIX},MAIN_DOMAIN=pcioasis.com,LABS_PROJECT_ID=${LABS_PROJECT_ID},ENABLE_AUTH=true,REQUIRE_AUTH=true,FIREBASE_PROJECT_ID=ui-firebase-pcioasis-${ENVIRONMENT},PUBLIC_BASE_URL=https://${DOMAIN_PREFIX}" \
  --update-secrets=/etc/secrets/dotenvx-key=${DOTENVX_SECRET_NAME}:latest \
  --labels="environment=${ENVIRONMENT},component=index,project=e-skimming-labs-home,traefik_enable=true,traefik_http_routers_home-index_rule_id=home-index-root,traefik_http_routers_home-index_priority=1,traefik_http_routers_home-index_entrypoints=web,traefik_http_routers_home-index_middlewares=forwarded-headers-file,traefik_http_services_home-index_lb_port=8080,traefik_http_routers_home-index-signin_rule_id=home-index-signin,traefik_http_routers_home-index-signin_priority=100,traefik_http_routers_home-index-signin_entrypoints=web,traefik_http_routers_home-index-signin_middlewares=signin-headers-file,traefik_http_routers_home-index-signin_service=home-index"

echo "   ✅ Index service deployed"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "✅ Home services deployed successfully!"
echo ""
echo "📋 Service URLs:"
gcloud run services describe home-seo-${ENVIRONMENT} \
  --region=${HOME_GAR_LOCATION} \
  --project=${HOME_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   SEO: /' || echo "   SEO: (not available)"

gcloud run services describe home-index-${ENVIRONMENT} \
  --region=${HOME_GAR_LOCATION} \
  --project=${HOME_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Index: /' || echo "   Index: (not available)"
