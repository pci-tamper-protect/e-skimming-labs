#!/bin/bash
# Deploy Labs Services to Cloud Run (gcloud only, no Terraform)
# This script builds, pushes, and deploys lab services
# Usage: ./deploy/deploy-labs.sh [stg|prd] [lab-number|all] [image-tag] [--force-rebuild]
#        lab-number: 01, 02, 03, 04, or "all" (default: all)
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
LAB_NUMBER="all"
FORCE_REBUILD=false
IMAGE_TAG=""

for arg in "$@"; do
  if [ "$arg" = "--force-rebuild" ]; then
    FORCE_REBUILD=true
  elif [ "$arg" = "stg" ] || [ "$arg" = "prd" ]; then
    ENVIRONMENT="$arg"
  elif [ "$arg" = "01" ] || [ "$arg" = "02" ] || [ "$arg" = "03" ] || [ "$arg" = "04" ] || [ "$arg" = "all" ]; then
    LAB_NUMBER="$arg"
  elif [ -z "$IMAGE_TAG" ] && [ "$arg" != "--force-rebuild" ]; then
    IMAGE_TAG="$arg"
  fi
done

# Require environment
if [ -z "$ENVIRONMENT" ]; then
  echo "❌ Environment required: stg or prd"
  echo "Usage: $0 [stg|prd] [01|02|03|04|all] [image-tag] [--force-rebuild]"
  exit 1
fi

# Load environment variables
source "$SCRIPT_DIR/load-env.sh"

# Configuration based on environment
if [ "$ENVIRONMENT" = "stg" ]; then
  LABS_PROJECT_ID="${LABS_PROJECT_ID:-labs-stg}"
  DOMAIN_PREFIX="labs.stg.pcioasis.com"
else
  LABS_PROJECT_ID="${LABS_PROJECT_ID:-labs-prd}"
  DOMAIN_PREFIX="labs.pcioasis.com"
fi

LABS_GAR_LOCATION="${LABS_REGION:-us-central1}"
LABS_REPOSITORY="e-skimming-labs"

# Get image tag
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"

echo "🧪 Deploying Labs Services to Cloud Run..."
echo "   Environment: $ENVIRONMENT"
echo "   Project: $LABS_PROJECT_ID"
echo "   Region: $LABS_GAR_LOCATION"
echo "   Lab(s): $LAB_NUMBER"
echo "   Image tag: $IMAGE_TAG"
if [ "$FORCE_REBUILD" = true ]; then
  echo "   ⚠️  Force rebuild: enabled"
fi
echo ""

cd "$REPO_ROOT"

# Source generated Cloud Run labels (from docker-compose.yml)
source "$SCRIPT_DIR/traefik/lab-labels.sh"

# Authenticate to Artifact Registry
echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker ${LABS_GAR_LOCATION}-docker.pkg.dev --quiet

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
# DEPLOY ANALYTICS SERVICE (shared by all labs)
# ============================================================================

deploy_analytics() {
  echo ""
  echo "📊 Deploying labs-analytics-${ENVIRONMENT}..."
  ANALYTICS_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:${IMAGE_TAG}"

  build_and_push \
    "labs-analytics-${ENVIRONMENT}" \
    "deploy/shared-components/analytics-service" \
    "Dockerfile" \
    "$ANALYTICS_IMAGE" \
    "--build-arg ENVIRONMENT=$ENVIRONMENT"

  gcloud run deploy labs-analytics-${ENVIRONMENT} \
    --image="$ANALYTICS_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=5 \
    --set-env-vars="PROJECT_ID=${LABS_PROJECT_ID},LABS_PROJECT_ID=${LABS_PROJECT_ID},ENVIRONMENT=${ENVIRONMENT},FIRESTORE_DATABASE=(default)" \
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
    --labels="environment=${ENVIRONMENT},component=analytics,project=e-skimming-labs,$(get_lab_labels labs-analytics)"

  echo "   ✅ Analytics service deployed"
}

# ============================================================================
# LAB 1: Basic Magecart
# ============================================================================

deploy_lab01() {
  echo ""
  echo "🔬 Deploying Lab 01: Basic Magecart..."

  # Lab 1 C2 Server
  echo "   📦 Building lab1-c2-${ENVIRONMENT}..."
  LAB1_C2_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:${IMAGE_TAG}"

  build_and_push \
    "lab1-c2-${ENVIRONMENT}" \
    "labs/01-basic-magecart/malicious-code/c2-server" \
    "Dockerfile" \
    "$LAB1_C2_IMAGE"

  LAB1_C2_TRAEFIK_LABELS=$(get_lab_labels "lab1-c2-server")

  gcloud run deploy lab1-c2-${ENVIRONMENT} \
    --image="$LAB1_C2_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=256Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=5 \
    --set-env-vars="ENVIRONMENT=${ENVIRONMENT}" \
    --labels="environment=${ENVIRONMENT},component=c2,lab=01-basic-magecart,project=e-skimming-labs,${LAB1_C2_TRAEFIK_LABELS}"

  echo "   ✅ Lab 1 C2 deployed"

  # Lab 1 Main Service
  echo "   📦 Building lab-01-basic-magecart-${ENVIRONMENT}..."
  LAB1_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:${IMAGE_TAG}"

  build_and_push \
    "lab-01-basic-magecart-${ENVIRONMENT}" \
    "labs/01-basic-magecart" \
    "Dockerfile" \
    "$LAB1_IMAGE"

  TRAEFIK_LABELS=$(get_lab_labels "lab1-vulnerable-site")

  gcloud run deploy lab-01-basic-magecart-${ENVIRONMENT} \
    --image="$LAB1_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --set-env-vars="LAB_NAME=01-basic-magecart,ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},HOME_URL=https://${DOMAIN_PREFIX},C2_URL=https://${DOMAIN_PREFIX}/lab1/c2" \
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
    --labels="environment=${ENVIRONMENT},lab=01-basic-magecart,project=e-skimming-labs,${TRAEFIK_LABELS}"

  echo "   ✅ Lab 1 Main deployed"
}

# ============================================================================
# LAB 2: DOM Skimming
# ============================================================================

deploy_lab02() {
  echo ""
  echo "🔬 Deploying Lab 02: DOM Skimming..."

  # Lab 2 C2 Server
  echo "   📦 Building lab2-c2-${ENVIRONMENT}..."
  LAB2_C2_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:${IMAGE_TAG}"

  build_and_push \
    "lab2-c2-${ENVIRONMENT}" \
    "labs/02-dom-skimming/c2-server" \
    "Dockerfile" \
    "$LAB2_C2_IMAGE"

  LAB2_C2_TRAEFIK_LABELS=$(get_lab_labels "lab2-c2-server")

  gcloud run deploy lab2-c2-${ENVIRONMENT} \
    --image="$LAB2_C2_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=256Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=5 \
    --set-env-vars="ENVIRONMENT=${ENVIRONMENT},C2_STANDALONE=true" \
    --labels="environment=${ENVIRONMENT},component=c2,lab=02-dom-skimming,project=e-skimming-labs,${LAB2_C2_TRAEFIK_LABELS}"

  echo "   ✅ Lab 2 C2 deployed"

  # Lab 2 Main Service
  echo "   📦 Building lab-02-dom-skimming-${ENVIRONMENT}..."
  LAB2_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:${IMAGE_TAG}"

  build_and_push \
    "lab-02-dom-skimming-${ENVIRONMENT}" \
    "labs/02-dom-skimming" \
    "Dockerfile" \
    "$LAB2_IMAGE"

  TRAEFIK_LABELS=$(get_lab_labels "lab2-vulnerable-site")

  gcloud run deploy lab-02-dom-skimming-${ENVIRONMENT} \
    --image="$LAB2_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --set-env-vars="LAB_NAME=02-dom-skimming,ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},HOME_URL=https://${DOMAIN_PREFIX},C2_URL=https://${DOMAIN_PREFIX}/lab2/c2" \
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
    --labels="environment=${ENVIRONMENT},lab=02-dom-skimming,project=e-skimming-labs,${TRAEFIK_LABELS}"

  echo "   ✅ Lab 2 Main deployed"
}

# ============================================================================
# LAB 3: Extension Hijacking
# ============================================================================

deploy_lab03() {
  echo ""
  echo "🔬 Deploying Lab 03: Extension Hijacking..."

  # Lab 3 Extension Server
  echo "   📦 Building lab3-extension-${ENVIRONMENT}..."
  LAB3_EXT_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:${IMAGE_TAG}"

  build_and_push \
    "lab3-extension-${ENVIRONMENT}" \
    "labs/03-extension-hijacking/test-server" \
    "Dockerfile" \
    "$LAB3_EXT_IMAGE"

  LAB3_EXT_TRAEFIK_LABELS=$(get_lab_labels "lab3-extension-server")

  gcloud run deploy lab3-extension-${ENVIRONMENT} \
    --image="$LAB3_EXT_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=256Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=5 \
    --set-env-vars="ENVIRONMENT=${ENVIRONMENT}" \
    --labels="environment=${ENVIRONMENT},component=extension,lab=03-extension-hijacking,project=e-skimming-labs,${LAB3_EXT_TRAEFIK_LABELS}"

  echo "   ✅ Lab 3 Extension deployed"

  # Lab 3 Main Service
  echo "   📦 Building lab-03-extension-hijacking-${ENVIRONMENT}..."
  LAB3_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:${IMAGE_TAG}"

  build_and_push \
    "lab-03-extension-hijacking-${ENVIRONMENT}" \
    "labs/03-extension-hijacking" \
    "Dockerfile" \
    "$LAB3_IMAGE"

  TRAEFIK_LABELS=$(get_lab_labels "lab3-vulnerable-site")

  gcloud run deploy lab-03-extension-hijacking-${ENVIRONMENT} \
    --image="$LAB3_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --set-env-vars="LAB_NAME=03-extension-hijacking,ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},HOME_URL=https://${DOMAIN_PREFIX},C2_URL=https://${DOMAIN_PREFIX}/lab3/extension" \
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
    --labels="environment=${ENVIRONMENT},lab=03-extension-hijacking,project=e-skimming-labs,${TRAEFIK_LABELS}"

  echo "   ✅ Lab 3 Main deployed"
}

# ============================================================================
# LAB 4: Steganography / Favicon Trojan
# ============================================================================

deploy_lab04() {
  echo ""
  echo "🔬 Deploying Lab 04: Steganography..."

  # Lab 4 C2 Server
  echo "   📦 Building lab4-c2-${ENVIRONMENT}..."
  LAB4_C2_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab4-c2:${IMAGE_TAG}"

  build_and_push \
    "lab4-c2-${ENVIRONMENT}" \
    "labs/04-steganography-favicon/malicious-code/c2-server" \
    "Dockerfile" \
    "$LAB4_C2_IMAGE"

  LAB4_C2_TRAEFIK_LABELS=$(get_lab_labels "lab4-c2-server")

  gcloud run deploy lab4-c2-${ENVIRONMENT} \
    --image="$LAB4_C2_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=256Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=5 \
    --set-env-vars="ENVIRONMENT=${ENVIRONMENT},PORT=8080" \
    --labels="environment=${ENVIRONMENT},component=c2,lab=04-steganography,project=e-skimming-labs,${LAB4_C2_TRAEFIK_LABELS}"

  echo "   ✅ Lab 4 C2 deployed"

  # Lab 4 Main Service
  echo "   📦 Building lab-04-steganography-${ENVIRONMENT}..."
  LAB4_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/04-steganography:${IMAGE_TAG}"

  build_and_push \
    "lab-04-steganography-${ENVIRONMENT}" \
    "labs/04-steganography-favicon/vulnerable-site" \
    "Dockerfile" \
    "$LAB4_IMAGE"

  TRAEFIK_LABELS=$(get_lab_labels "lab4-vulnerable-site")

  gcloud run deploy lab-04-steganography-${ENVIRONMENT} \
    --image="$LAB4_IMAGE" \
    --region=${LABS_GAR_LOCATION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --set-env-vars="LAB_NAME=04-steganography,ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},HOME_URL=https://${DOMAIN_PREFIX},C2_URL=https://${DOMAIN_PREFIX}/lab4/c2" \
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
    --labels="environment=${ENVIRONMENT},lab=04-steganography,project=e-skimming-labs,${TRAEFIK_LABELS}"

  echo "   ✅ Lab 4 Main deployed"
}

# ============================================================================
# MAIN DEPLOYMENT LOGIC
# ============================================================================

# Deploy analytics (shared service) only when deploying all labs
if [ "$LAB_NUMBER" = "all" ]; then
  deploy_analytics
fi

# Deploy requested lab(s)
case "$LAB_NUMBER" in
  "01")
    deploy_lab01
    ;;
  "02")
    deploy_lab02
    ;;
  "03")
    deploy_lab03
    ;;
  "04")
    deploy_lab04
    ;;
  "all")
    deploy_lab01
    deploy_lab02
    deploy_lab03
    deploy_lab04
    ;;
esac

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "✅ Labs deployment complete!"
echo ""
echo "📋 Deployed services:"
if [ "$LAB_NUMBER" = "all" ]; then
  echo "   - labs-analytics-${ENVIRONMENT}"
fi

case "$LAB_NUMBER" in
  "01"|"all")
    echo "   - lab1-c2-${ENVIRONMENT}"
    echo "   - lab-01-basic-magecart-${ENVIRONMENT}"
    ;;&
  "02"|"all")
    echo "   - lab2-c2-${ENVIRONMENT}"
    echo "   - lab-02-dom-skimming-${ENVIRONMENT}"
    ;;&
  "03"|"all")
    echo "   - lab3-extension-${ENVIRONMENT}"
    echo "   - lab-03-extension-hijacking-${ENVIRONMENT}"
    ;;&
  "04"|"all")
    echo "   - lab4-c2-${ENVIRONMENT}"
    echo "   - lab-04-steganography-${ENVIRONMENT}"
    ;;
esac
