#!/bin/bash
# Deploy all services to staging
# This script builds, pushes, and deploys all services to Cloud Run staging
# Usage: ./deploy/deploy-all-stg.sh [image-tag] [--force-rebuild]
#        If image-tag is not provided, uses current git SHA
#        --force-rebuild: Force rebuild even if files haven't changed

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
FORCE_REBUILD=false
IMAGE_TAG=""
for arg in "$@"; do
  if [ "$arg" = "--force-rebuild" ]; then
    FORCE_REBUILD=true
  elif [ -z "$IMAGE_TAG" ] && [ "$arg" != "--force-rebuild" ]; then
    IMAGE_TAG="$arg"
  fi
done

# Configuration
ENVIRONMENT="stg"
HOME_PROJECT_ID="labs-home-stg"
LABS_PROJECT_ID="labs-stg"
HOME_GAR_LOCATION="us-central1"
LABS_GAR_LOCATION="us-central1"
HOME_REPOSITORY="e-skimming-labs-home"
LABS_REPOSITORY="e-skimming-labs"
DOMAIN_PREFIX="labs.stg.pcioasis.com"

# Get image tag (git SHA or provided argument)
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"

echo "🚀 Deploying all services to staging..."
echo "   Image tag: $IMAGE_TAG"
echo "   Environment: $ENVIRONMENT"
echo "   Home Project: $HOME_PROJECT_ID"
echo "   Labs Project: $LABS_PROJECT_ID"
if [ "$FORCE_REBUILD" = true ]; then
  echo "   ⚠️  Force rebuild: enabled (will rebuild all images)"
fi
echo ""

# Get repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Authenticate to Artifact Registry
echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker ${HOME_GAR_LOCATION}-docker.pkg.dev --quiet
gcloud auth configure-docker ${LABS_GAR_LOCATION}-docker.pkg.dev --quiet

# Function to calculate content hash for a directory
# This hash represents the content of all files that would affect the build
calculate_content_hash() {
  local build_dir="$1"
  local dockerfile="$2"
  
  # Find all files that could affect the build
  # Include Dockerfile, source files, dependencies, config files
  # Note: build_dir is relative to repo root
  (
    cd "$REPO_ROOT" || return 1
    
    # Find all relevant source files in build directory and hash them
    # Note: Dockerfile is included via -name "Dockerfile*" pattern, so no need to hash it separately
    if [ "$build_dir" = "." ]; then
      # Building from repo root - hash all relevant files
      find . -type f \( \
        -name "*.go" -o \
        -name "*.mod" -o \
        -name "*.sum" -o \
        -name "Dockerfile*" -o \
        -name "go.*" -o \
        -name "*.js" -o \
        -name "*.jsx" -o \
        -name "*.ts" -o \
        -name "*.tsx" -o \
        -name "package.json" -o \
        -name "package-lock.json" -o \
        -name "yarn.lock" -o \
        -name "*.py" -o \
        -name "requirements.txt" -o \
        -name "Pipfile" -o \
        -name "*.html" -o \
        -name "*.css" \
      \) ! -path "*/node_modules/*" ! -path "*/.git/*" \
        -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
    else
      # Building from subdirectory - only hash files in that directory
      if [ -d "$build_dir" ]; then
        cd "$build_dir" || return 1
        find . -type f \( \
          -name "*.go" -o \
          -name "*.mod" -o \
          -name "*.sum" -o \
          -name "Dockerfile*" -o \
          -name "go.*" -o \
          -name "*.js" -o \
          -name "*.jsx" -o \
          -name "*.ts" -o \
          -name "*.tsx" -o \
          -name "package.json" -o \
          -name "package-lock.json" -o \
          -name "yarn.lock" -o \
          -name "*.py" -o \
          -name "requirements.txt" -o \
          -name "Pipfile" -o \
          -name "*.html" -o \
          -name "*.css" \
        \) ! -path "*/node_modules/*" \
          -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
      fi
    fi
  )
}

# Function to check if image exists locally
image_exists_local() {
  local image="$1"
  docker image inspect "$image" &>/dev/null
}

# Function to check if image exists in Artifact Registry
image_exists_remote() {
  local image="$1"
  local project="$2"
  local location="$3"
  
  gcloud artifacts docker images describe "$image" \
    --project="$project" \
    --location="$location" \
    --format="value(name)" &>/dev/null
}

# Function to build and push image if needed
# Returns 0 if build was skipped, 1 if build was performed
build_and_push_if_needed() {
  local service_name="$1"
  local build_dir="$2"
  local dockerfile="$3"
  local image_tag="$4"
  local project_id="$5"
  local location="$6"
  local build_args="${7:-}"  # Optional build args
  
  echo ""
  echo "📦 Checking $service_name..."
  echo "   Directory: $build_dir"
  echo "   Image: $image_tag"
  
  # Extract base image name (without tag)
  local base_image
  base_image="${image_tag%:*}"
  local latest_tag="${base_image}:latest"
  
  # Skip check if force rebuild
  if [ "$FORCE_REBUILD" = true ]; then
    echo "   ⚠️  Force rebuild enabled, building..."
  else
    # Calculate content hash
    local content_hash
    content_hash=$(calculate_content_hash "$build_dir" "$dockerfile")
    if [ -z "$content_hash" ]; then
      echo "   ⚠️  Could not calculate content hash, building to be safe..."
    else
      echo "   Content hash: $content_hash"
      
      # Check if image with content hash tag exists (local first, then remote)
      local hash_image_tag="${base_image}:${content_hash}"
      
      if image_exists_local "$hash_image_tag"; then
        echo "   ✅ Image with content hash exists locally: $hash_image_tag"
        echo "   ℹ️  Source files haven't changed, skipping build"
        echo "   📤 Tagging local image..."
        # Tag the local image with new tags
        docker tag "$hash_image_tag" "$image_tag" 2>/dev/null || true
        docker tag "$hash_image_tag" "$latest_tag" 2>/dev/null || true
        # Push the tags to remote
        docker push "$image_tag" 2>/dev/null || true
        docker push "$latest_tag" 2>/dev/null || true
        return 0
      elif image_exists_remote "$hash_image_tag" "$project_id" "$location"; then
        echo "   ✅ Image with content hash already exists in Artifact Registry: $hash_image_tag"
        echo "   ℹ️  Source files haven't changed, skipping build"
        echo "   📤 Tagging existing image..."
        # Pull, tag, and push the existing image with new tags
        docker pull "$hash_image_tag" 2>/dev/null || true
        docker tag "$hash_image_tag" "$image_tag" 2>/dev/null || true
        docker tag "$hash_image_tag" "$latest_tag" 2>/dev/null || true
        docker push "$image_tag" 2>/dev/null || true
        docker push "$latest_tag" 2>/dev/null || true
        return 0
      fi
      
      echo "   ℹ️  Image with content hash not found, will build..."
    fi
  fi
  
  # Build the image
  echo "   🔨 Building image..."
  
  # Determine build context (usually build_dir, but for some services it's repo root)
  local build_context="."
  if [ "$build_dir" != "." ]; then
    build_context="$build_dir"
  fi
  
  # Build command - dockerfile path is relative to build context
  local dockerfile_path="$dockerfile"
  if [ "$build_dir" = "." ]; then
    # If building from repo root, dockerfile path is already correct
    dockerfile_path="$dockerfile"
  else
    # If building from subdirectory, dockerfile should be relative to that dir
    # But we pass it as -f, so it can be relative to build context or absolute
    if [ "${dockerfile#/}" = "$dockerfile" ]; then
      # Relative path - check if it's relative to build_dir or repo root
      if [ -f "$build_dir/$dockerfile" ]; then
        dockerfile_path="$dockerfile"
      elif [ -f "$dockerfile" ]; then
        dockerfile_path="$dockerfile"
      fi
    fi
  fi
  
  cd "$REPO_ROOT"
  cd "$build_context" || { echo "❌ Build directory not found: $build_context"; exit 1; }
  
  # Build command
  local build_cmd="docker build"
  if [ -n "$build_args" ]; then
    build_cmd="$build_cmd $build_args"
  fi
  build_cmd="$build_cmd -f \"$dockerfile_path\" -t \"$image_tag\" -t \"$latest_tag\""
  
  # Add content hash tag if available
  if [ -n "$content_hash" ] && [ "$FORCE_REBUILD" != true ]; then
    local hash_tag="${base_image}:${content_hash}"
    build_cmd="$build_cmd -t \"$hash_tag\""
  fi
  
  # Execute build (build context is current directory)
  eval "$build_cmd ." || { echo "❌ Failed to build $service_name image"; exit 1; }
  
  # Push all tags
  echo "   📤 Pushing image..."
  docker push "$image_tag"
  docker push "$latest_tag"
  if [ -n "$content_hash" ] && [ "$FORCE_REBUILD" != true ]; then
    local hash_tag="${base_image}:${content_hash}"
    docker push "$hash_tag"
  fi
  
  echo "   ✅ $service_name image built and pushed"
  return 1
}

# Function to grant IAM access
grant_iam_access() {
  local service_name=$1
  local region=$2
  local project_id=$3

  echo "   👥 Granting IAM access..."
  gcloud run services add-iam-policy-binding "${service_name}" \
    --region="${region}" \
    --project="${project_id}" \
    --member="group:2025-interns@pcioasis.com" \
    --role="roles/run.invoker" \
    --quiet || echo "     ⚠️  Failed to grant access to 2025-interns (may already exist)"

  gcloud run services add-iam-policy-binding "${service_name}" \
    --region="${region}" \
    --project="${project_id}" \
    --member="group:core-eng@pcioasis.com" \
    --role="roles/run.invoker" \
    --quiet || echo "     ⚠️  Failed to grant access to core-eng (may already exist)"
}

# ============================================================================
# HOME PROJECT SERVICES
# ============================================================================

echo "📦 Deploying Home Project Services..."
echo ""

# 1. Deploy SEO Service
echo "1️⃣  Deploying home-seo-${ENVIRONMENT}..."
SEO_IMAGE="${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:${IMAGE_TAG}"
build_and_push_if_needed \
  "home-seo-${ENVIRONMENT}" \
  "deploy/shared-components/seo-service" \
  "Dockerfile" \
  "$SEO_IMAGE" \
  "$HOME_PROJECT_ID" \
  "$HOME_GAR_LOCATION" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

gcloud run deploy home-seo-${ENVIRONMENT} \
  --image=${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:${IMAGE_TAG} \
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
  --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
  --labels="environment=${ENVIRONMENT},component=seo,project=e-skimming-labs-home,traefik_enable=true,traefik_http_routers_home-seo_rule_id=home-seo,traefik_http_routers_home-seo_priority=500,traefik_http_routers_home-seo_entrypoints=web,traefik_http_routers_home-seo_middlewares=strip-seo-prefix-file,traefik_http_services_home-seo_lb_port=8080"

grant_iam_access "home-seo-${ENVIRONMENT}" "${HOME_GAR_LOCATION}" "${HOME_PROJECT_ID}"
echo "   ✅ SEO service deployed"
echo ""

# 2. Deploy Index Service
echo "2️⃣  Deploying home-index-${ENVIRONMENT}..."
INDEX_IMAGE="${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG}"
build_and_push_if_needed \
  "home-index-${ENVIRONMENT}" \
  "." \
  "deploy/shared-components/home-index-service/Dockerfile" \
  "$INDEX_IMAGE" \
  "$HOME_PROJECT_ID" \
  "$HOME_GAR_LOCATION" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

gcloud run deploy home-index-${ENVIRONMENT} \
  --image=${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG} \
  --region=${HOME_GAR_LOCATION} \
  --platform=managed \
  --project=${HOME_PROJECT_ID} \
  --no-allow-unauthenticated \
  --service-account=fbase-adm-sdk-runtime@${HOME_PROJECT_ID}.iam.gserviceaccount.com \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=5 \
  --set-env-vars="HOME_PROJECT_ID=${HOME_PROJECT_ID},ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},LABS_DOMAIN=${DOMAIN_PREFIX},MAIN_DOMAIN=pcioasis.com,LABS_PROJECT_ID=${LABS_PROJECT_ID},LAB1_URL=https://lab-01-basic-magecart-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app,LAB2_URL=https://lab-02-dom-skimming-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app/banking.html,LAB3_URL=https://lab-03-extension-hijacking-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app/index.html,ENABLE_AUTH=true,REQUIRE_AUTH=true,FIREBASE_PROJECT_ID=ui-firebase-pcioasis-${ENVIRONMENT}" \
  --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
  --labels="environment=${ENVIRONMENT},component=index,project=e-skimming-labs-home,traefik_enable=true,traefik_http_routers_home-index_rule_id=home-index-root,traefik_http_routers_home-index_priority=1,traefik_http_routers_home-index_entrypoints=web,traefik_http_routers_home-index_middlewares=forwarded-headers-file,traefik_http_services_home-index_lb_port=8080,traefik_http_routers_home-index-signin_rule_id=home-index-signin,traefik_http_routers_home-index-signin_priority=100,traefik_http_routers_home-index-signin_entrypoints=web,traefik_http_routers_home-index-signin_middlewares=signin-headers-file,traefik_http_routers_home-index-signin_service=home-index"

grant_iam_access "home-index-${ENVIRONMENT}" "${HOME_GAR_LOCATION}" "${HOME_PROJECT_ID}"
echo "   ✅ Index service deployed"
echo ""

# ============================================================================
# LABS PROJECT SERVICES
# ============================================================================

echo "📦 Deploying Labs Project Services..."
echo ""

# 3. Deploy Analytics Service
echo "3️⃣  Deploying labs-analytics-${ENVIRONMENT}..."
ANALYTICS_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:${IMAGE_TAG}"
build_and_push_if_needed \
  "labs-analytics-${ENVIRONMENT}" \
  "deploy/shared-components/analytics-service" \
  "Dockerfile" \
  "$ANALYTICS_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

gcloud run deploy labs-analytics-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:${IMAGE_TAG} \
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
  --labels="environment=${ENVIRONMENT},component=analytics,project=e-skimming-labs,traefik_enable=true,traefik_http_routers_labs-analytics_rule_id=labs-analytics,traefik_http_routers_labs-analytics_priority=500,traefik_http_routers_labs-analytics_entrypoints=web,traefik_http_routers_labs-analytics_middlewares=strip-analytics-prefix-file,traefik_http_services_labs-analytics_lb_port=8080"

grant_iam_access "labs-analytics-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Analytics service deployed"
echo ""

# 4. Deploy Labs Index Service
echo "4️⃣  Deploying labs-index-${ENVIRONMENT}..."
LABS_INDEX_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/index:${IMAGE_TAG}"
build_and_push_if_needed \
  "labs-index-${ENVIRONMENT}" \
  "." \
  "deploy/Dockerfile.index" \
  "$LABS_INDEX_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION" \
  "--build-arg ENVIRONMENT=$ENVIRONMENT"

gcloud run deploy labs-index-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/index:${IMAGE_TAG} \
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
  --set-env-vars="ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},ANALYTICS_SERVICE_URL=https://labs-analytics-${ENVIRONMENT}-hash.a.run.app,SEO_SERVICE_URL=https://labs-seo-${ENVIRONMENT}-hash.a.run.app" \
  --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
  --labels="environment=${ENVIRONMENT},component=index,project=e-skimming-labs"

grant_iam_access "labs-index-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Labs Index service deployed"
echo ""

# 5. Deploy Lab 1 C2 Service
echo "5️⃣  Deploying lab1-c2-${ENVIRONMENT} (C2 server for Lab 1)..."
LAB1_C2_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:${IMAGE_TAG}"
build_and_push_if_needed \
  "lab1-c2-${ENVIRONMENT}" \
  "labs/01-basic-magecart/malicious-code/c2-server" \
  "Dockerfile" \
  "$LAB1_C2_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION"

# Traefik labels for Lab 1 C2 at /lab1/c2 (using rule_id to avoid GCP label restrictions)
LAB1_C2_TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab1-c2_rule_id=lab1-c2,traefik_http_routers_lab1-c2_priority=300,traefik_http_routers_lab1-c2_entrypoints=web,traefik_http_routers_lab1-c2_middlewares=strip-lab1-c2-prefix-file,traefik_http_routers_lab1-c2_service=lab1-c2-server,traefik_http_services_lab1-c2-server_lb_port=8080"

gcloud run deploy lab1-c2-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:${IMAGE_TAG} \
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

grant_iam_access "lab1-c2-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Lab 1 C2 service deployed at /lab1/c2"
echo ""

# 6. Deploy Lab 2 C2 Service
echo "6️⃣  Deploying lab2-c2-${ENVIRONMENT} (C2 server for Lab 2)..."
LAB2_C2_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:${IMAGE_TAG}"
build_and_push_if_needed \
  "lab2-c2-${ENVIRONMENT}" \
  "labs/02-dom-skimming" \
  "Dockerfile.c2" \
  "$LAB2_C2_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION"

# Traefik labels for Lab 2 C2 at /lab2/c2
LAB2_C2_TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab2-c2_rule_id=lab2-c2,traefik_http_routers_lab2-c2_priority=300,traefik_http_routers_lab2-c2_entrypoints=web,traefik_http_routers_lab2-c2_middlewares=strip-lab2-c2-prefix-file,traefik_http_routers_lab2-c2_service=lab2-c2-server,traefik_http_services_lab2-c2-server_lb_port=8080"

gcloud run deploy lab2-c2-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:${IMAGE_TAG} \
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
  --labels="environment=${ENVIRONMENT},component=c2,lab=02-dom-skimming,project=e-skimming-labs,${LAB2_C2_TRAEFIK_LABELS}"

grant_iam_access "lab2-c2-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Lab 2 C2 service deployed at /lab2/c2"
echo ""

# 7. Deploy Lab 3 Extension Service (acts as C2 for Lab 3)
echo "7️⃣  Deploying lab3-extension-${ENVIRONMENT} (extension server for Lab 3)..."
LAB3_EXT_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:${IMAGE_TAG}"
build_and_push_if_needed \
  "lab3-extension-${ENVIRONMENT}" \
  "labs/03-extension-hijacking/test-server" \
  "Dockerfile" \
  "$LAB3_EXT_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION"

# Traefik labels for Lab 3 extension at /lab3/extension
LAB3_EXT_TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab3-extension_rule_id=lab3-extension,traefik_http_routers_lab3-extension_priority=300,traefik_http_routers_lab3-extension_entrypoints=web,traefik_http_routers_lab3-extension_middlewares=strip-lab3-extension-prefix-file,traefik_http_routers_lab3-extension_service=lab3-extension-server,traefik_http_services_lab3-extension-server_lb_port=8080"

gcloud run deploy lab3-extension-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:${IMAGE_TAG} \
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

grant_iam_access "lab3-extension-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Lab 3 extension service deployed at /lab3/extension"
echo ""

# 8. Deploy Lab 1
echo "8️⃣  Deploying lab-01-basic-magecart-${ENVIRONMENT}..."
LAB1_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:${IMAGE_TAG}"
build_and_push_if_needed \
  "lab-01-basic-magecart-${ENVIRONMENT}" \
  "labs/01-basic-magecart" \
  "Dockerfile" \
  "$LAB1_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION"

# Remove lab1-c2 router from main lab service (C2 is now separate)
TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab1-static_rule_id=lab1-static,traefik_http_routers_lab1-static_priority=250,traefik_http_routers_lab1-static_entrypoints=web,traefik_http_routers_lab1-static_middlewares=strip-lab1-prefix-file,traefik_http_routers_lab1-static_service=lab1,traefik_http_routers_lab1_rule_id=lab1,traefik_http_routers_lab1_priority=200,traefik_http_routers_lab1_entrypoints=web,traefik_http_routers_lab1_middlewares=lab1-auth-check-file__strip-lab1-prefix-file,traefik_http_routers_lab1_service=lab1,traefik_http_services_lab1_lb_port=8080"

gcloud run deploy lab-01-basic-magecart-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:${IMAGE_TAG} \
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

grant_iam_access "lab-01-basic-magecart-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Lab 1 deployed"
echo ""

# 9. Deploy Lab 2
echo "9️⃣  Deploying lab-02-dom-skimming-${ENVIRONMENT}..."
LAB2_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:${IMAGE_TAG}"
build_and_push_if_needed \
  "lab-02-dom-skimming-${ENVIRONMENT}" \
  "labs/02-dom-skimming" \
  "Dockerfile" \
  "$LAB2_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION"

# Remove lab2-c2 route from main lab service (C2 is now separate)
TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab2-static_rule_id=lab2-static,traefik_http_routers_lab2-static_priority=250,traefik_http_routers_lab2-static_entrypoints=web,traefik_http_routers_lab2-static_middlewares=strip-lab2-prefix-file,traefik_http_routers_lab2-static_service=lab2-vulnerable-site,traefik_http_routers_lab2-main_rule_id=lab2,traefik_http_routers_lab2-main_priority=200,traefik_http_routers_lab2-main_entrypoints=web,traefik_http_routers_lab2-main_middlewares=lab2-auth-check-file__strip-lab2-prefix-file,traefik_http_services_lab2-vulnerable-site_lb_port=8080"

gcloud run deploy lab-02-dom-skimming-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:${IMAGE_TAG} \
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

grant_iam_access "lab-02-dom-skimming-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Lab 2 deployed"
echo ""

# 10. Deploy Lab 3
echo "🔟 Deploying lab-03-extension-hijacking-${ENVIRONMENT}..."
LAB3_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:${IMAGE_TAG}"
build_and_push_if_needed \
  "lab-03-extension-hijacking-${ENVIRONMENT}" \
  "labs/03-extension-hijacking" \
  "Dockerfile" \
  "$LAB3_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION"

# Remove lab3-extension route from main lab service (extension is now separate)
TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab3-static_rule_id=lab3-static,traefik_http_routers_lab3-static_priority=250,traefik_http_routers_lab3-static_entrypoints=web,traefik_http_routers_lab3-static_middlewares=strip-lab3-prefix-file,traefik_http_routers_lab3-static_service=lab3-vulnerable-site,traefik_http_routers_lab3-main_rule_id=lab3,traefik_http_routers_lab3-main_priority=200,traefik_http_routers_lab3-main_entrypoints=web,traefik_http_routers_lab3-main_middlewares=lab3-auth-check-file__strip-lab3-prefix-file,traefik_http_services_lab3-vulnerable-site_lb_port=8080"

gcloud run deploy lab-03-extension-hijacking-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:${IMAGE_TAG} \
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

grant_iam_access "lab-03-extension-hijacking-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Lab 3 deployed"
echo ""

# 11. Deploy Traefik
echo "1️⃣1️⃣ Deploying traefik-${ENVIRONMENT}..."
echo "   🔧 Setting up Traefik Cloud Run plugin..."
cd "$REPO_ROOT/deploy/traefik"
./setup-plugin.sh || {
    echo "❌ ERROR: Failed to setup plugin. Make sure traefik-cloudrun-provider is a sibling directory."
    exit 1
}
cd "$REPO_ROOT"
echo ""

TRAEFIK_IMAGE="${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/traefik:${IMAGE_TAG}"
build_and_push_if_needed \
  "traefik-${ENVIRONMENT}" \
  "deploy/traefik" \
  "Dockerfile.cloudrun" \
  "$TRAEFIK_IMAGE" \
  "$LABS_PROJECT_ID" \
  "$LABS_GAR_LOCATION"

gcloud run deploy traefik-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/traefik:${IMAGE_TAG} \
  --region=${LABS_GAR_LOCATION} \
  --platform=managed \
  --project=${LABS_PROJECT_ID} \
  --no-allow-unauthenticated \
  --service-account=traefik-${ENVIRONMENT}@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=1 \
  --max-instances=5 \
  --set-env-vars="ENVIRONMENT=${ENVIRONMENT},LABS_PROJECT_ID=${LABS_PROJECT_ID},HOME_PROJECT_ID=${HOME_PROJECT_ID},MAIN_DOMAIN=pcioasis.com,LABS_DOMAIN=${DOMAIN_PREFIX}" \
  --labels="environment=${ENVIRONMENT},component=traefik,project=e-skimming-labs"

grant_iam_access "traefik-${ENVIRONMENT}" "${LABS_GAR_LOCATION}" "${LABS_PROJECT_ID}"
echo "   ✅ Traefik deployed"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "✅ All services deployed successfully!"
echo ""
echo "📋 Service URLs:"
echo ""
echo "Home Project Services:"
gcloud run services describe home-seo-${ENVIRONMENT} \
  --region=${HOME_GAR_LOCATION} \
  --project=${HOME_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   SEO: /' || echo "   SEO: (not available)"

gcloud run services describe home-index-${ENVIRONMENT} \
  --region=${HOME_GAR_LOCATION} \
  --project=${HOME_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Index: /' || echo "   Index: (not available)"

echo ""
echo "Labs Project Services:"
gcloud run services describe labs-analytics-${ENVIRONMENT} \
  --region=${LABS_GAR_LOCATION} \
  --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Analytics: /' || echo "   Analytics: (not available)"

gcloud run services describe labs-index-${ENVIRONMENT} \
  --region=${LABS_GAR_LOCATION} \
  --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Labs Index: /' || echo "   Labs Index: (not available)"

gcloud run services describe lab-01-basic-magecart-${ENVIRONMENT} \
  --region=${LABS_GAR_LOCATION} \
  --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Lab 1: /' || echo "   Lab 1: (not available)"

gcloud run services describe lab-02-dom-skimming-${ENVIRONMENT} \
  --region=${LABS_GAR_LOCATION} \
  --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Lab 2: /' || echo "   Lab 2: (not available)"

gcloud run services describe lab-03-extension-hijacking-${ENVIRONMENT} \
  --region=${LABS_GAR_LOCATION} \
  --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Lab 3: /' || echo "   Lab 3: (not available)"

gcloud run services describe traefik-${ENVIRONMENT} \
  --region=${LABS_GAR_LOCATION} \
  --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Traefik: /' || echo "   Traefik: (not available)"

echo ""
echo "🌐 Access via Traefik:"
echo "   https://${DOMAIN_PREFIX}"
echo ""
echo "💡 Note: Services are protected - only members of 2025-interns and core-eng groups can access"
echo ""
