#!/bin/bash
# Build and push Docker images for shared components
# This script builds the analytics, seo, and home-index services

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment configuration using dotenvx (supports encrypted .env files)
source "$SCRIPT_DIR/load-env.sh"

LABS_PROJECT_ID="${LABS_PROJECT_ID:-}"
HOME_PROJECT_ID="${HOME_PROJECT_ID:-}"
REGION="${LABS_REGION:-${HOME_REGION:-us-central1}}"

# Determine environment from project ID
if [[ "$LABS_PROJECT_ID" == *"-stg" ]] || [[ "$HOME_PROJECT_ID" == *"-stg" ]]; then
    ENVIRONMENT="stg"
elif [[ "$LABS_PROJECT_ID" == *"-prd" ]] || [[ "$HOME_PROJECT_ID" == *"-prd" ]]; then
    ENVIRONMENT="prd"
else
    echo "❌ Cannot determine environment from project IDs:"
    echo "   LABS_PROJECT_ID: ${LABS_PROJECT_ID:-not set}"
    echo "   HOME_PROJECT_ID: ${HOME_PROJECT_ID:-not set}"
    echo "   Project IDs must end with -stg or -prd"
    echo "   Or set ENVIRONMENT environment variable explicitly (stg or prd)"
    exit 1
fi

# Verify environment is explicitly set
if [ -z "$ENVIRONMENT" ]; then
    echo "❌ ENVIRONMENT must be explicitly set (stg or prd)"
    echo "   Set it in .env file or as environment variable"
    exit 1
fi

echo "🏗️  Building and pushing Docker images"
echo "======================================"
echo "Labs Project ID: ${LABS_PROJECT_ID:-not set}"
echo "Home Project ID: ${HOME_PROJECT_ID:-not set}"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo ""

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is authenticated with gcloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
    echo "❌ No active gcloud authentication found."
    echo "   Please run: gcloud auth login"
    exit 1
fi

# Configure Docker to use gcloud as a credential helper
echo "🔐 Configuring Docker authentication..."
# Authenticate with both the target project and the base image project
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
# Also authenticate with pcioasis-operations for base images (if not already done)
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet || true

# Function to check if image exists in Artifact Registry
image_exists() {
    local image="$1"
    local project="$2"
    local location="$3"
    
    gcloud artifacts docker images describe "$image" \
        --project="$project" \
        --location="$location" \
        --format="value(name)" &>/dev/null
}

# Build and push analytics service (to labs project)
if [ -n "$LABS_PROJECT_ID" ]; then
    echo ""
    echo "📦 Building analytics service for labs project..."
    gcloud config set project "$LABS_PROJECT_ID"
    cd "$SCRIPT_DIR/shared-components/analytics-service"
    REPOSITORY="e-skimming-labs"
    IMAGE_NAME="${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${REPOSITORY}/analytics:latest"
    
    # Check if image already exists
    if image_exists "$IMAGE_NAME" "$LABS_PROJECT_ID" "$REGION"; then
        echo "   ℹ️  Image already exists: $IMAGE_NAME"
        echo "   ⚠️  Rebuilding anyway (use build-images-optimized.sh to skip if unchanged)"
    fi
    
    echo "   🔨 Building image..."
    docker build -t "$IMAGE_NAME" .
    echo "   📤 Pushing image..."
    docker push "$IMAGE_NAME"
    echo "✅ Analytics service image pushed: $IMAGE_NAME"
fi

# Build and push SEO and home-index services (to home project)
if [ -n "$HOME_PROJECT_ID" ]; then
    echo ""
    echo "📦 Building SEO and home-index services for home project..."
    gcloud config set project "$HOME_PROJECT_ID"
    REPOSITORY="e-skimming-labs-home"
    
    # Check if repository exists, create if it doesn't
    if ! gcloud artifacts repositories describe "$REPOSITORY" --location="$REGION" --project="$HOME_PROJECT_ID" &>/dev/null; then
        echo "  Creating Artifact Registry repository $REPOSITORY..."
        gcloud artifacts repositories create "$REPOSITORY" \
            --repository-format=docker \
            --location="$REGION" \
            --project="$HOME_PROJECT_ID" \
            --description="E-Skimming Labs Home Page container images" || {
            echo "⚠️  Failed to create repository. It may already exist or you may need to deploy terraform-home first."
        }
    fi
    
    # Build SEO service
    echo "  Building SEO service..."
    cd "$SCRIPT_DIR/shared-components/seo-service"
    SEO_IMAGE="${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/${REPOSITORY}/seo:latest"
    
    # Check if image already exists
    if image_exists "$SEO_IMAGE" "$HOME_PROJECT_ID" "$REGION"; then
        echo "     ℹ️  Image already exists: $SEO_IMAGE"
        echo "     ⚠️  Rebuilding anyway (use build-images-optimized.sh to skip if unchanged)"
    fi
    
    echo "     🔨 Building image..."
    docker build -t "$SEO_IMAGE" .
    echo "     📤 Pushing image..."
    docker push "$SEO_IMAGE"
    echo "✅ SEO service image pushed: $SEO_IMAGE"
    
    # Build home-index service (must be built from repo root due to COPY paths)
    echo "  Building home-index service..."
    # Get the repo root (one level up from deploy/)
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    cd "$REPO_ROOT"
    INDEX_IMAGE="${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/${REPOSITORY}/index:latest"
    
    # Check if image already exists
    if image_exists "$INDEX_IMAGE" "$HOME_PROJECT_ID" "$REGION"; then
        echo "     ℹ️  Image already exists: $INDEX_IMAGE"
        echo "     ⚠️  Rebuilding anyway (use build-images-optimized.sh to skip if unchanged)"
    fi
    
    echo "     🔨 Building image..."
    docker build -f "$SCRIPT_DIR/shared-components/home-index-service/Dockerfile" -t "$INDEX_IMAGE" .
    echo "     📤 Pushing image..."
    docker push "$INDEX_IMAGE"
    echo "✅ Home-index service image pushed: $INDEX_IMAGE"
fi

echo ""
echo "✅ All images built and pushed successfully!"
echo ""
echo "Images built:"
if [ -n "$LABS_PROJECT_ID" ]; then
    echo "  - Analytics: ${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/e-skimming-labs/analytics:latest"
fi
if [ -n "$HOME_PROJECT_ID" ]; then
    echo "  - SEO: ${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/e-skimming-labs-home/seo:latest"
    echo "  - Home-Index: ${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/e-skimming-labs-home/index:latest"
fi

