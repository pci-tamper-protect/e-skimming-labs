#!/bin/bash
# Deploy all pre-built services to Cloud Run
# Usage: ./deploy/deploy-all.sh [stg|prd] [image-tag] [--only service1,service2]
#        image-tag: tag of pre-built images (default: current git SHA)
#        --only: Comma-separated list of services to deploy (e.g. --only home-index,traefik)
#                Services: home-seo, home-index, labs-analytics, labs-index,
#                          shared-c2,
#                          lab-01-basic-magecart, lab-02-dom-skimming, lab-03-extension-hijacking,
#                          lab-04-steganography, traefik
#        Called by build-deploy-all.sh after images are built, or standalone
#        when images already exist in Artifact Registry.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Lab Traefik labels are generated from docker-compose.yml (single source of truth).
# Re-run deploy/traefik/generate-lab-labels.sh to regenerate after docker-compose changes.
source "$SCRIPT_DIR/traefik/lab-labels.sh"

source "$SCRIPT_DIR/check-credentials.sh"
if ! check_credentials; then
  echo ""
  echo "❌ Deployment aborted: Please fix credential issues first"
  exit 1
fi
echo ""

# Parse arguments
ENVIRONMENT=""
IMAGE_TAG=""
ONLY_SERVICES=""
NEXT_IS_ONLY=false
for arg in "$@"; do
  if [ "$NEXT_IS_ONLY" = true ]; then
    ONLY_SERVICES="$arg"
    NEXT_IS_ONLY=false
  elif [ "$arg" = "--only" ]; then
    NEXT_IS_ONLY=true
  elif [ "$arg" = "stg" ] || [ "$arg" = "prd" ]; then
    ENVIRONMENT="$arg"
  elif [ -z "$IMAGE_TAG" ] && [ "$arg" != "--only" ]; then
    IMAGE_TAG="$arg"
  fi
done

# Helper: returns 0 (true) if the service should be deployed
should_run() {
  local svc="$1"
  [ -z "$ONLY_SERVICES" ] && return 0
  echo ",$ONLY_SERVICES," | grep -q ",${svc},"
}

if [ -z "$ENVIRONMENT" ]; then
  echo "❌ Environment required: stg or prd"
  echo "Usage: $0 [stg|prd] [image-tag] [--only svc1,svc2]"
  exit 1
fi

# Configuration derived from environment
ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
HOME_PROJECT_ID="labs-home-${ENVIRONMENT}"
LABS_PROJECT_ID="labs-${ENVIRONMENT}"
REGION="us-central1"
HOME_REPOSITORY="e-skimming-labs-home"
LABS_REPOSITORY="e-skimming-labs"
if [ "$ENVIRONMENT" = "prd" ]; then
  DOMAIN_PREFIX="labs.pcioasis.com"
else
  DOMAIN_PREFIX="labs.stg.pcioasis.com"
fi

# Resolve IMAGE_TAG: prefer explicit arg, then short SHA, then full SHA (used by CI), then latest.
# CI tags images with the full github.sha; local builds use the short SHA.
if [ -z "$IMAGE_TAG" ]; then
  SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null || true)
  FULL_SHA=$(git rev-parse HEAD 2>/dev/null || true)
  # Probe Artifact Registry for a known service image to find which tag format was pushed.
  PROBE_REPO="${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/shared-c2"
  if [ -n "$SHORT_SHA" ] && gcloud artifacts docker tags list "$PROBE_REPO" \
       --project="${LABS_PROJECT_ID}" --filter="tag=$SHORT_SHA" --format="value(tag)" 2>/dev/null | grep -q .; then
    IMAGE_TAG="$SHORT_SHA"
  elif [ -n "$FULL_SHA" ] && gcloud artifacts docker tags list "$PROBE_REPO" \
       --project="${LABS_PROJECT_ID}" --filter="tag=$FULL_SHA" --format="value(tag)" 2>/dev/null | grep -q .; then
    IMAGE_TAG="$FULL_SHA"
  else
    IMAGE_TAG="latest"
  fi
fi

echo "🚀 Deploying all services to ${ENVIRONMENT}..."
echo "   Image tag: $IMAGE_TAG"
echo "   Home Project: $HOME_PROJECT_ID"
echo "   Labs Project: $LABS_PROJECT_ID"
if [ -n "$ONLY_SERVICES" ]; then
  echo "   🎯 Only: $ONLY_SERVICES"
fi
echo ""

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Enable required APIs on both GCP projects before any deployment.
# identitytoolkit.googleapis.com must be enabled on the CALLING project (labs-home-*)
# because Google checks API quota/enablement against the service account's project,
# not the Firebase project. Without this, CreateSessionCookie returns 403.
ensure_service_enabled() {
  local project_id=$1
  shift
  local service
  for service in "$@"; do
    if gcloud services list \
      --project="${project_id}" \
      --filter="config.name=${service}" \
      --limit=1 \
      --format="value(config.name)" \
      | grep -q "${service}"; then
      echo "   ✔ ${service} already enabled on ${project_id}"
    else
      echo "   🔧 Enabling ${service} on ${project_id}..."
      gcloud services enable "${service}" --project="${project_id}" --quiet
      echo "   ✅ ${service} enabled"
    fi
  done
}

echo "🔧 Ensuring required APIs are enabled..."
ensure_service_enabled "${HOME_PROJECT_ID}" \
  identitytoolkit.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com
ensure_service_enabled "${LABS_PROJECT_ID}" \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  storage.googleapis.com
echo ""
echo ""

# GCS bucket names for shared-c2 per-lab storage
C2_BUCKET_LAB1="labs-c2-lab1-${ENVIRONMENT}"
C2_BUCKET_LAB2="labs-c2-lab2-${ENVIRONMENT}"
C2_BUCKET_LAB3="labs-c2-lab3-${ENVIRONMENT}"
C2_BUCKET_LAB4="labs-c2-lab4-${ENVIRONMENT}"
C2_SA="labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com"

# Ensure C2 GCS buckets exist with correct IAM (idempotent)
ensure_c2_buckets() {
  for bucket in "$C2_BUCKET_LAB1" "$C2_BUCKET_LAB2" "$C2_BUCKET_LAB3" "$C2_BUCKET_LAB4"; do
    if ! gcloud storage buckets describe "gs://${bucket}" --project="${LABS_PROJECT_ID}" &>/dev/null; then
      echo "   Creating bucket gs://${bucket}..."
      gcloud storage buckets create "gs://${bucket}" \
        --project="${LABS_PROJECT_ID}" \
        --location="${REGION}" \
        --uniform-bucket-level-access \
        --quiet
    fi
    gcloud storage buckets add-iam-policy-binding "gs://${bucket}" \
      --member="serviceAccount:${C2_SA}" \
      --role="roles/storage.objectAdmin" \
      --quiet 2>/dev/null || true
  done
  echo "   ✅ C2 GCS buckets ready"
}

if should_run "shared-c2"; then
  echo "🪣 Ensuring C2 GCS buckets..."
  ensure_c2_buckets
  echo ""
fi

grant_iam_access() {
  local service_name=$1
  local project_id=$2

  gcloud run services add-iam-policy-binding "${service_name}" \
    --region="${REGION}" \
    --project="${project_id}" \
    --member="group:2025-interns@pcioasis.com" \
    --role="roles/run.invoker" \
    --quiet || echo "     ⚠️  Failed to grant access to 2025-interns (may already exist)"

  gcloud run services add-iam-policy-binding "${service_name}" \
    --region="${REGION}" \
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

if should_run "home-seo"; then
  echo "1️⃣  Deploying home-seo-${ENVIRONMENT}..."
  gcloud run deploy home-seo-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:${IMAGE_TAG} \
    --region=${REGION} \
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
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_${ENV_UPPER}:latest \
    --labels="environment=${ENVIRONMENT},component=seo,project=e-skimming-labs-home,traefik_enable=true,traefik_http_routers_home-seo_rule_id=home-seo,traefik_http_routers_home-seo_priority=500,traefik_http_routers_home-seo_entrypoints=web,traefik_http_routers_home-seo_middlewares=strip-seo-prefix-file,traefik_http_services_home-seo_lb_port=8080"
  grant_iam_access "home-seo-${ENVIRONMENT}" "${HOME_PROJECT_ID}"
  echo "   ✅ SEO service deployed"
  echo ""
fi

if should_run "home-index"; then
  echo "2️⃣  Deploying home-index-${ENVIRONMENT}..."
  # PRD: home-index must be public so Traefik's forwardAuth can call /api/auth/check without relying on
  # a valid identity token. Terraform (terraform-home/cloud-run.tf home_index_public) also enforces this.
  # STG: Keep private; Traefik SA has run.invoker via Terraform (terraform-home/iap.tf traefik_index_access).
  if [ "${ENVIRONMENT}" = "prd" ]; then
    HOME_INDEX_AUTH_FLAG="--allow-unauthenticated"
  else
    HOME_INDEX_AUTH_FLAG="--no-allow-unauthenticated"
  fi
  gcloud run deploy home-index-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG} \
    --region=${REGION} \
    --platform=managed \
    --project=${HOME_PROJECT_ID} \
    ${HOME_INDEX_AUTH_FLAG} \
    --service-account=fbase-adm-sdk-runtime@${HOME_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=5 \
    --set-env-vars="HOME_PROJECT_ID=${HOME_PROJECT_ID},ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},LABS_DOMAIN=${DOMAIN_PREFIX},MAIN_DOMAIN=pcioasis.com,LABS_PROJECT_ID=${LABS_PROJECT_ID},LAB1_URL=https://lab-01-basic-magecart-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app,LAB2_URL=https://lab-02-dom-skimming-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app/banking.html,LAB3_URL=https://lab-03-extension-hijacking-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app/index.html,ENABLE_AUTH=true,REQUIRE_AUTH=true,FIREBASE_PROJECT_ID=ui-firebase-pcioasis-${ENVIRONMENT},PUBLIC_BASE_URL=https://${DOMAIN_PREFIX}" \
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_${ENV_UPPER}:latest \
    --labels="environment=${ENVIRONMENT},component=index,project=e-skimming-labs-home,traefik_enable=true,traefik_http_routers_home-index_rule_id=home-index-root,traefik_http_routers_home-index_priority=1,traefik_http_routers_home-index_entrypoints=web,traefik_http_routers_home-index_middlewares=forwarded-headers-file,traefik_http_services_home-index_lb_port=8080,traefik_http_routers_home-index-signin_rule_id=home-index-signin,traefik_http_routers_home-index-signin_priority=100,traefik_http_routers_home-index-signin_entrypoints=web,traefik_http_routers_home-index-signin_middlewares=signin-headers-file,traefik_http_routers_home-index-signin_service=home-index"
  grant_iam_access "home-index-${ENVIRONMENT}" "${HOME_PROJECT_ID}"
  echo "   ✅ Index service deployed"
  echo ""
fi

# ============================================================================
# LABS PROJECT SERVICES
# ============================================================================

echo "📦 Deploying Labs Project Services..."
echo ""

if should_run "labs-analytics"; then
  echo "3️⃣  Deploying labs-analytics-${ENVIRONMENT}..."
  gcloud run deploy labs-analytics-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:${IMAGE_TAG} \
    --region=${REGION} \
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
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_${ENV_UPPER}:latest \
    --labels="environment=${ENVIRONMENT},component=analytics,project=e-skimming-labs,traefik_enable=true,traefik_http_routers_labs-analytics_rule_id=labs-analytics,traefik_http_routers_labs-analytics_priority=500,traefik_http_routers_labs-analytics_entrypoints=web,traefik_http_routers_labs-analytics_middlewares=strip-analytics-prefix-file,traefik_http_services_labs-analytics_lb_port=8080"
  grant_iam_access "labs-analytics-${ENVIRONMENT}" "${LABS_PROJECT_ID}"
  echo "   ✅ Analytics service deployed"
  echo ""
fi

if should_run "labs-index"; then
  echo "4️⃣  Deploying labs-index-${ENVIRONMENT}..."
  gcloud run deploy labs-index-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/index:${IMAGE_TAG} \
    --region=${REGION} \
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
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_${ENV_UPPER}:latest \
    --labels="environment=${ENVIRONMENT},component=index,project=e-skimming-labs"
  grant_iam_access "labs-index-${ENVIRONMENT}" "${LABS_PROJECT_ID}"
  echo "   ✅ Labs Index service deployed"
  echo ""
fi

if should_run "shared-c2"; then
  echo "5️⃣  Deploying shared-c2-${ENVIRONMENT}..."
  SHARED_C2_TRAEFIK_LABELS=$(get_lab_labels "shared-c2")
  # shared-c2 stays private; Traefik forwards only the intended /lab*/c2 routes
  gcloud run deploy shared-c2-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/shared-c2:${IMAGE_TAG} \
    --region=${REGION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=3000 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=1 \
    --max-instances=5 \
    --set-env-vars="ENVIRONMENT=${ENVIRONMENT},LAB1_BUCKET=${C2_BUCKET_LAB1},LAB2_BUCKET=${C2_BUCKET_LAB2},LAB3_BUCKET=${C2_BUCKET_LAB3},LAB4_BUCKET=${C2_BUCKET_LAB4}" \
    --labels="environment=${ENVIRONMENT},component=shared-c2,project=e-skimming-labs,${SHARED_C2_TRAEFIK_LABELS}"
  echo "   ✅ Shared C2 deployed"
  echo ""
fi

if should_run "lab-01-basic-magecart"; then
  echo "8️⃣  Deploying lab-01-basic-magecart-${ENVIRONMENT}..."
  LAB1_TRAEFIK_LABELS=$(get_lab_labels "lab1-vulnerable-site")
  gcloud run deploy lab-01-basic-magecart-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:${IMAGE_TAG} \
    --region=${REGION} \
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
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_${ENV_UPPER}:latest \
    --labels="environment=${ENVIRONMENT},lab=01-basic-magecart,project=e-skimming-labs,${LAB1_TRAEFIK_LABELS}"
  grant_iam_access "lab-01-basic-magecart-${ENVIRONMENT}" "${LABS_PROJECT_ID}"
  echo "   ✅ Lab 1 deployed"
  echo ""
fi

if should_run "lab-02-dom-skimming"; then
  echo "9️⃣  Deploying lab-02-dom-skimming-${ENVIRONMENT}..."
  LAB2_TRAEFIK_LABELS=$(get_lab_labels "lab2-vulnerable-site")
  gcloud run deploy lab-02-dom-skimming-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:${IMAGE_TAG} \
    --region=${REGION} \
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
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_${ENV_UPPER}:latest \
    --labels="environment=${ENVIRONMENT},lab=02-dom-skimming,project=e-skimming-labs,${LAB2_TRAEFIK_LABELS}"
  grant_iam_access "lab-02-dom-skimming-${ENVIRONMENT}" "${LABS_PROJECT_ID}"
  echo "   ✅ Lab 2 deployed"
  echo ""
fi

if should_run "lab-03-extension-hijacking"; then
  echo "🔟 Deploying lab-03-extension-hijacking-${ENVIRONMENT}..."
  LAB3_TRAEFIK_LABELS=$(get_lab_labels "lab3-vulnerable-site")
  gcloud run deploy lab-03-extension-hijacking-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:${IMAGE_TAG} \
    --region=${REGION} \
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
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_${ENV_UPPER}:latest \
    --labels="environment=${ENVIRONMENT},lab=03-extension-hijacking,project=e-skimming-labs,${LAB3_TRAEFIK_LABELS}"
  grant_iam_access "lab-03-extension-hijacking-${ENVIRONMENT}" "${LABS_PROJECT_ID}"
  echo "   ✅ Lab 3 deployed"
  echo ""
fi

if should_run "lab-04-steganography"; then
  echo "1️⃣1️⃣ Deploying lab-04-steganography-${ENVIRONMENT}..."
  LAB4_TRAEFIK_LABELS=$(get_lab_labels "lab4-vulnerable-site")
  gcloud run deploy lab-04-steganography-${ENVIRONMENT} \
    --image=${REGION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/04-steganography-favicon:${IMAGE_TAG} \
    --region=${REGION} \
    --platform=managed \
    --project=${LABS_PROJECT_ID} \
    --no-allow-unauthenticated \
    --service-account=labs-runtime-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com \
    --port=8080 \
    --memory=256Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --set-env-vars="LAB_NAME=04-steganography,ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},HOME_URL=https://${DOMAIN_PREFIX},C2_URL=https://${DOMAIN_PREFIX}/lab4/c2" \
    --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_${ENV_UPPER}:latest \
    --labels="environment=${ENVIRONMENT},lab=04-steganography,project=e-skimming-labs,${LAB4_TRAEFIK_LABELS}"
  grant_iam_access "lab-04-steganography-${ENVIRONMENT}" "${LABS_PROJECT_ID}"
  echo "   ✅ Lab 4 deployed"
  echo ""
fi

# ============================================================================
# TRAEFIK (sidecar architecture - build + deploy handled by dedicated script)
# ============================================================================

if should_run "traefik"; then
  echo "1️⃣1️⃣ Deploying traefik-${ENVIRONMENT} (sidecar)..."
  "$SCRIPT_DIR/traefik/deploy-sidecar-traefik-3.0.sh" "${ENVIRONMENT}"
  echo ""
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo "✅ All services deployed successfully!"
echo ""
echo "📋 Service URLs:"
echo ""
echo "Home Project Services:"
gcloud run services describe home-seo-${ENVIRONMENT} \
  --region=${REGION} --project=${HOME_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   SEO: /' || echo "   SEO: (not available)"
gcloud run services describe home-index-${ENVIRONMENT} \
  --region=${REGION} --project=${HOME_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Index: /' || echo "   Index: (not available)"

echo ""
echo "Labs Project Services:"
gcloud run services describe labs-analytics-${ENVIRONMENT} \
  --region=${REGION} --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Analytics: /' || echo "   Analytics: (not available)"
gcloud run services describe labs-index-${ENVIRONMENT} \
  --region=${REGION} --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Labs Index: /' || echo "   Labs Index: (not available)"
gcloud run services describe lab-01-basic-magecart-${ENVIRONMENT} \
  --region=${REGION} --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Lab 1: /' || echo "   Lab 1: (not available)"
gcloud run services describe lab-02-dom-skimming-${ENVIRONMENT} \
  --region=${REGION} --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Lab 2: /' || echo "   Lab 2: (not available)"
gcloud run services describe lab-03-extension-hijacking-${ENVIRONMENT} \
  --region=${REGION} --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Lab 3: /' || echo "   Lab 3: (not available)"
gcloud run services describe lab-04-steganography-${ENVIRONMENT} \
  --region=${REGION} --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Lab 4: /' || echo "   Lab 4: (not available)"
gcloud run services describe traefik-${ENVIRONMENT} \
  --region=${REGION} --project=${LABS_PROJECT_ID} \
  --format="value(status.url)" 2>/dev/null | sed 's/^/   Traefik: /' || echo "   Traefik: (not available)"

echo ""
echo "🌐 Access via Traefik: https://${DOMAIN_PREFIX}"
echo ""
echo "💡 Note: Services are protected - only members of 2025-interns and core-eng groups can access"
echo ""
