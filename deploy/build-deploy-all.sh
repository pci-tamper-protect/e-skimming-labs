#!/bin/bash
# Build and push all service images, then deploy via deploy-all.sh
# Usage: ./deploy/build-deploy-all.sh [stg|prd] [image-tag] [--force-rebuild]
#        If image-tag is not provided, uses current git SHA
#        --force-rebuild: Rebuild even if content hash matches

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/check-credentials.sh"
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

if [ -z "$ENVIRONMENT" ]; then
  echo "❌ Environment required: stg or prd"
  echo "Usage: $0 [stg|prd] [image-tag] [--force-rebuild]"
  exit 1
fi

# Configuration derived from environment
HOME_PROJECT_ID="labs-home-${ENVIRONMENT}"
LABS_PROJECT_ID="labs-${ENVIRONMENT}"
REGION="us-central1"
HOME_REPOSITORY="e-skimming-labs-home"
LABS_REPOSITORY="e-skimming-labs"

IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"

echo "🏗️  Building and pushing all images for ${ENVIRONMENT}..."
echo "   Image tag: $IMAGE_TAG"
echo "   Home Project: $HOME_PROJECT_ID"
echo "   Labs Project: $LABS_PROJECT_ID"
if [ "$FORCE_REBUILD" = true ]; then
  echo "   ⚠️  Force rebuild: enabled"
fi
echo ""

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# ============================================================================
# BUILD FUNCTIONS
# ============================================================================

calculate_content_hash() {
  local build_dir="$1"
  (
    cd "$REPO_ROOT" || return 1
    if [ "$build_dir" = "." ]; then
      find . -type f \( \
        -name "*.go" -o -name "*.mod" -o -name "*.sum" -o -name "Dockerfile*" -o -name "go.*" -o \
        -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o \
        -name "package.json" -o -name "package-lock.json" -o -name "yarn.lock" -o \
        -name "*.py" -o -name "requirements.txt" -o -name "Pipfile" -o \
        -name "*.html" -o -name "*.css" \
      \) ! -path "*/node_modules/*" ! -path "*/.git/*" \
        -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
    else
      if [ -d "$build_dir" ]; then
        cd "$build_dir" || return 1
        find . -type f \( \
          -name "*.go" -o -name "*.mod" -o -name "*.sum" -o -name "Dockerfile*" -o -name "go.*" -o \
          -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o \
          -name "package.json" -o -name "package-lock.json" -o -name "yarn.lock" -o \
          -name "*.py" -o -name "requirements.txt" -o -name "Pipfile" -o \
          -name "*.html" -o -name "*.css" \
        \) ! -path "*/node_modules/*" \
          -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
      fi
    fi
  )
}

image_exists_local() { docker image inspect "$1" &>/dev/null; }

image_exists_remote() {
  gcloud artifacts docker images describe "$1" \
    --project="$2" --location="$3" --format="value(name)" &>/dev/null
}

build_and_push_if_needed() {
  local service_name="$1"
  local build_dir="$2"
  local dockerfile="$3"
  local image_tag="$4"
  local project_id="$5"
  local build_args="${6:-}"

  echo ""
  echo "📦 Checking $service_name..."
  echo "   Image: $image_tag"

  local base_image="${image_tag%:*}"
  local latest_tag="${base_image}:latest"

  if [ "$FORCE_REBUILD" = true ]; then
    echo "   ⚠️  Force rebuild enabled, building..."
  else
    local content_hash
    content_hash=$(calculate_content_hash "$build_dir")
    if [ -n "$content_hash" ]; then
      echo "   Content hash: $content_hash"
      local hash_tag="${base_image}:${content_hash}"

      if image_exists_local "$hash_tag"; then
        echo "   ✅ Unchanged (local cache hit), retagging and pushing..."
        docker tag "$hash_tag" "$image_tag" 2>/dev/null || true
        docker tag "$hash_tag" "$latest_tag" 2>/dev/null || true
        docker push "$image_tag" 2>/dev/null || true
        docker push "$latest_tag" 2>/dev/null || true
        return 0
      elif image_exists_remote "$hash_tag" "$project_id" "$REGION"; then
        echo "   ✅ Unchanged (remote cache hit), retagging and pushing..."
        docker pull "$hash_tag" 2>/dev/null || true
        docker tag "$hash_tag" "$image_tag" 2>/dev/null || true
        docker tag "$hash_tag" "$latest_tag" 2>/dev/null || true
        docker push "$image_tag" 2>/dev/null || true
        docker push "$latest_tag" 2>/dev/null || true
        return 0
      fi
      echo "   ℹ️  No cache hit, building..."
    else
      echo "   ⚠️  Could not calculate content hash, building to be safe..."
    fi
  fi

  echo "   🔨 Building image..."
  local abs_context
  if [ "$build_dir" = "." ]; then
    abs_context="$REPO_ROOT"
  else
    abs_context="$REPO_ROOT/$build_dir"
  fi
  local abs_dockerfile="$REPO_ROOT/$dockerfile"

  local build_cmd="docker build"
  [ -n "$build_args" ] && build_cmd="$build_cmd $build_args"
  build_cmd="$build_cmd -f \"$abs_dockerfile\" -t \"$image_tag\" -t \"$latest_tag\""

  if [ -n "${content_hash:-}" ] && [ "$FORCE_REBUILD" != true ]; then
    build_cmd="$build_cmd -t \"${base_image}:${content_hash}\""
  fi

  cd "$REPO_ROOT"
  eval "$build_cmd \"$abs_context\"" || { echo "❌ Failed to build $service_name"; exit 1; }

  echo "   📤 Pushing..."
  docker push "$image_tag"
  docker push "$latest_tag"
  [ -n "${content_hash:-}" ] && [ "$FORCE_REBUILD" != true ] && docker push "${base_image}:${content_hash}"

  echo "   ✅ $service_name built and pushed"
}

# ============================================================================
# BUILD ALL IMAGES
# ============================================================================

echo "📦 Building Home Project images..."

build_and_push_if_needed "home-seo" \
  "deploy/shared-components/seo-service" \
  "deploy/shared-components/seo-service/Dockerfile" \
  "${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:${IMAGE_TAG}" \
  "$HOME_PROJECT_ID" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

build_and_push_if_needed "home-index" \
  "." \
  "deploy/shared-components/home-index-service/Dockerfile" \
  "${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG}" \
  "$HOME_PROJECT_ID" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

echo ""
echo "📦 Building Labs Project images..."

build_and_push_if_needed "labs-analytics" \
  "deploy/shared-components/analytics-service" \
  "deploy/shared-components/analytics-service/Dockerfile" \
  "${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:${IMAGE_TAG}" \
  "$LABS_PROJECT_ID" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

build_and_push_if_needed "labs-index" \
  "." \
  "deploy/Dockerfile.index" \
  "${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/index:${IMAGE_TAG}" \
  "$LABS_PROJECT_ID" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

build_and_push_if_needed "lab1-c2" \
  "labs/01-basic-magecart/malicious-code/c2-server" \
  "labs/01-basic-magecart/malicious-code/c2-server/Dockerfile" \
  "${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:${IMAGE_TAG}" \
  "$LABS_PROJECT_ID"

build_and_push_if_needed "lab2-c2" \
  "labs/02-dom-skimming" \
  "labs/02-dom-skimming/Dockerfile.c2" \
  "${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:${IMAGE_TAG}" \
  "$LABS_PROJECT_ID"

build_and_push_if_needed "lab3-extension" \
  "labs/03-extension-hijacking/test-server" \
  "labs/03-extension-hijacking/test-server/Dockerfile" \
  "${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:${IMAGE_TAG}" \
  "$LABS_PROJECT_ID"

build_and_push_if_needed "lab-01-basic-magecart" \
  "labs/01-basic-magecart" \
  "labs/01-basic-magecart/Dockerfile" \
  "${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:${IMAGE_TAG}" \
  "$LABS_PROJECT_ID"

build_and_push_if_needed "lab-02-dom-skimming" \
  "labs/02-dom-skimming" \
  "labs/02-dom-skimming/Dockerfile" \
  "${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:${IMAGE_TAG}" \
  "$LABS_PROJECT_ID"

build_and_push_if_needed "lab-03-extension-hijacking" \
  "labs/03-extension-hijacking" \
  "labs/03-extension-hijacking/Dockerfile" \
  "${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:${IMAGE_TAG}" \
  "$LABS_PROJECT_ID"

echo ""
echo "✅ All images built and pushed. Handing off to deploy-all.sh..."
echo ""

# ============================================================================
# DEPLOY
# ============================================================================

"$SCRIPT_DIR/deploy-all.sh" "$ENVIRONMENT" "$IMAGE_TAG"
