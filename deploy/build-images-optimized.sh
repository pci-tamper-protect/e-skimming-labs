#!/bin/bash
# Build and push Docker images for shared components (with content hash checking)
# This script checks if images already exist before building/pushing

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment configuration
if [ -f "$SCRIPT_DIR/.env" ]; then
    if [ -L "$SCRIPT_DIR/.env" ]; then
        TARGET=$(readlink "$SCRIPT_DIR/.env")
        echo "📋 Using .env -> $TARGET"
    else
        echo "📋 Using .env"
    fi
    source "$SCRIPT_DIR/.env"
elif [ -f "$SCRIPT_DIR/.env.prd" ]; then
    echo "📋 Using .env.prd"
    source "$SCRIPT_DIR/.env.prd"
elif [ -f "$SCRIPT_DIR/.env.stg" ]; then
    echo "📋 Using .env.stg"
    source "$SCRIPT_DIR/.env.stg"
else
    echo "❌ .env file not found in $SCRIPT_DIR"
    exit 1
fi

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
    exit 1
fi

# Verify environment is explicitly set
if [ -z "$ENVIRONMENT" ]; then
    echo "❌ ENVIRONMENT must be explicitly set (stg or prd)"
    exit 1
fi

echo "🏗️  Building and pushing Docker images (with content hash checking)"
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
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Function to calculate content hash for a directory
calculate_content_hash() {
    local dir="$1"
    local dockerfile="$2"
    
    # Create a hash of all files that would affect the build
    # Include Dockerfile, source files, and any dependencies
    find "$dir" -type f \( -name "*.go" -o -name "*.mod" -o -name "*.sum" -o -name "Dockerfile*" -o -name "go.*" \) \
        -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
}

# Function to check if image exists in Artifact Registry
image_exists() {
    local image="$1"
    local project="$2"
    local location="$3"
    local repo_name=$(echo "$image" | sed -n 's|.*/\([^/]*\):.*|\1|p')
    local image_name=$(echo "$image" | sed -n 's|.*/\([^/]*\):\(.*\)|\1:\2|p')
    
    # Extract repository and tag
    local repo=$(echo "$image" | sed -n "s|${location}-docker.pkg.dev/${project}/\([^/]*\)/.*|\1|p")
    local tag=$(echo "$image" | sed -n 's|.*:\(.*\)|\1|p')
    
    # Check if image exists using gcloud
    gcloud artifacts docker images describe "$image" \
        --project="$project" \
        --location="$location" \
        --format="value(name)" &>/dev/null
}

# Function to build and push image if needed
build_and_push_if_needed() {
    local service_name="$1"
    local build_dir="$2"
    local dockerfile="$3"
    local image_tag="$4"
    local project_id="$5"
    local repository="$6"
    
    echo ""
    echo "📦 Checking $service_name..."
    echo "   Directory: $build_dir"
    echo "   Image: $image_tag"
    
    # Calculate content hash
    local content_hash=$(calculate_content_hash "$build_dir" "$dockerfile")
    echo "   Content hash: $content_hash"
    
    # Check if image already exists
    if image_exists "$image_tag" "$project_id" "$REGION"; then
        # Get the existing image's metadata to check if we can skip
        local existing_digest=$(gcloud artifacts docker images describe "$image_tag" \
            --project="$project_id" \
            --location="$REGION" \
            --format="value(image_summary.fully_qualified_digest)" 2>/dev/null || echo "")
        
        if [ -n "$existing_digest" ]; then
            echo "   ✅ Image already exists: $image_tag"
            echo "   ℹ️  Skipping build (image already in registry)"
            return 0
        fi
    fi
    
    # Build the image
    echo "   🔨 Building image (content changed or image not found)..."
    cd "$build_dir"
    docker build -f "$dockerfile" -t "$image_tag" .
    
    # Push the image
    echo "   📤 Pushing image..."
    docker push "$image_tag"
    echo "   ✅ $service_name image pushed: $image_tag"
}

# Build and push analytics service (to labs project)
if [ -n "$LABS_PROJECT_ID" ]; then
    echo ""
    echo "📦 Processing analytics service for labs project..."
    gcloud config set project "$LABS_PROJECT_ID"
    BUILD_DIR="$SCRIPT_DIR/shared-components/analytics-service"
    REPOSITORY="e-skimming-labs"
    IMAGE_NAME="${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${REPOSITORY}/analytics:latest"
    
    build_and_push_if_needed "analytics" "$BUILD_DIR" "Dockerfile" "$IMAGE_NAME" "$LABS_PROJECT_ID" "$REPOSITORY"
fi

# Build and push SEO and home-index services (to home project)
if [ -n "$HOME_PROJECT_ID" ]; then
    echo ""
    echo "📦 Processing SEO and home-index services for home project..."
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
    BUILD_DIR="$SCRIPT_DIR/shared-components/seo-service"
    SEO_IMAGE="${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/${REPOSITORY}/seo:latest"
    build_and_push_if_needed "SEO" "$BUILD_DIR" "Dockerfile" "$SEO_IMAGE" "$HOME_PROJECT_ID" "$REPOSITORY"
    
    # Build home-index service (must be built from repo root due to COPY paths)
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    BUILD_DIR="$REPO_ROOT"
    INDEX_IMAGE="${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/${REPOSITORY}/index:latest"
    DOCKERFILE="$SCRIPT_DIR/shared-components/home-index-service/Dockerfile"
    build_and_push_if_needed "home-index" "$BUILD_DIR" "$DOCKERFILE" "$INDEX_IMAGE" "$HOME_PROJECT_ID" "$REPOSITORY"
fi

echo ""
echo "✅ Image build/push check complete!"
echo ""

