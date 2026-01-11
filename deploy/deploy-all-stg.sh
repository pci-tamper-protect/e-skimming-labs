#!/bin/bash
# Deploy all services to staging
# This script builds, pushes, and deploys all services to Cloud Run staging
# Usage: ./deploy/deploy-all-stg.sh [image-tag]
#        If image-tag is not provided, uses current git SHA

set -e

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
IMAGE_TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"

echo "🚀 Deploying all services to staging..."
echo "   Image tag: $IMAGE_TAG"
echo "   Environment: $ENVIRONMENT"
echo "   Home Project: $HOME_PROJECT_ID"
echo "   Labs Project: $LABS_PROJECT_ID"
echo ""

# Get repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Authenticate to Artifact Registry
echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker ${HOME_GAR_LOCATION}-docker.pkg.dev --quiet
gcloud auth configure-docker ${LABS_GAR_LOCATION}-docker.pkg.dev --quiet

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
docker build \
  -f deploy/shared-components/seo-service/Dockerfile \
  --build-arg ENVIRONMENT=$ENVIRONMENT \
  -t ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:${IMAGE_TAG} \
  -t ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:latest \
  deploy/shared-components/seo-service || { echo "❌ Failed to build SEO image"; exit 1; }

docker push ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:${IMAGE_TAG}
docker push ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:latest

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
docker build \
  -f deploy/shared-components/home-index-service/Dockerfile \
  --build-arg ENVIRONMENT=$ENVIRONMENT \
  -t ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG} \
  -t ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:latest \
  . || { echo "❌ Failed to build Index image"; exit 1; }

docker push ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG}
docker push ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:latest

gcloud run deploy home-index-${ENVIRONMENT} \
  --image=${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG} \
  --region=${HOME_GAR_LOCATION} \
  --platform=managed \
  --project=${HOME_PROJECT_ID} \
  --allow-unauthenticated \
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
docker build \
  -f deploy/shared-components/analytics-service/Dockerfile \
  --build-arg ENVIRONMENT=$ENVIRONMENT \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:latest \
  deploy/shared-components/analytics-service || { echo "❌ Failed to build Analytics image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/analytics:latest

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
docker build \
  -f deploy/Dockerfile.index \
  --build-arg ENVIRONMENT=$ENVIRONMENT \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/index:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/index:latest \
  . || { echo "❌ Failed to build Labs Index image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/index:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/index:latest

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
docker build \
  -f labs/01-basic-magecart/malicious-code/c2-server/Dockerfile \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:latest \
  labs/01-basic-magecart/malicious-code/c2-server || { echo "❌ Failed to build Lab 1 C2 image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:latest

# Traefik labels for Lab 1 C2 at /lab1/c2 (using rule_id to avoid GCP label restrictions)
LAB1_C2_TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab1-c2_rule_id=lab1-c2,traefik_http_routers_lab1-c2_priority=300,traefik_http_routers_lab1-c2_entrypoints=web,traefik_http_routers_lab1-c2_middlewares=strip-lab1-c2-prefix-file,traefik_http_routers_lab1-c2_service=lab1-c2-server,traefik_http_services_lab1-c2-server_lb_port=8080"

gcloud run deploy lab1-c2-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab1-c2:${IMAGE_TAG} \
  --region=${LABS_GAR_LOCATION} \
  --platform=managed \
  --project=${LABS_PROJECT_ID} \
  --allow-unauthenticated \
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
docker build \
  -f labs/02-dom-skimming/Dockerfile.c2 \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:latest \
  labs/02-dom-skimming || { echo "❌ Failed to build Lab 2 C2 image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:latest

# Traefik labels for Lab 2 C2 at /lab2/c2
LAB2_C2_TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab2-c2_rule_id=lab2-c2,traefik_http_routers_lab2-c2_priority=300,traefik_http_routers_lab2-c2_entrypoints=web,traefik_http_routers_lab2-c2_middlewares=strip-lab2-c2-prefix-file,traefik_http_routers_lab2-c2_service=lab2-c2-server,traefik_http_services_lab2-c2-server_lb_port=8080"

gcloud run deploy lab2-c2-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab2-c2:${IMAGE_TAG} \
  --region=${LABS_GAR_LOCATION} \
  --platform=managed \
  --project=${LABS_PROJECT_ID} \
  --allow-unauthenticated \
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
docker build \
  -f labs/03-extension-hijacking/test-server/Dockerfile \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:latest \
  labs/03-extension-hijacking/test-server || { echo "❌ Failed to build Lab 3 extension image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:latest

# Traefik labels for Lab 3 extension at /lab3/extension
LAB3_EXT_TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab3-extension_rule_id=lab3-extension,traefik_http_routers_lab3-extension_priority=300,traefik_http_routers_lab3-extension_entrypoints=web,traefik_http_routers_lab3-extension_middlewares=strip-lab3-extension-prefix-file,traefik_http_routers_lab3-extension_service=lab3-extension-server,traefik_http_services_lab3-extension-server_lb_port=8080"

gcloud run deploy lab3-extension-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/lab3-extension:${IMAGE_TAG} \
  --region=${LABS_GAR_LOCATION} \
  --platform=managed \
  --project=${LABS_PROJECT_ID} \
  --allow-unauthenticated \
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
docker build \
  -f labs/01-basic-magecart/Dockerfile \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:latest \
  labs/01-basic-magecart || { echo "❌ Failed to build Lab 1 image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:latest

# Remove lab1-c2 router from main lab service (C2 is now separate)
TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab1-static_rule_id=lab1-static,traefik_http_routers_lab1-static_priority=250,traefik_http_routers_lab1-static_entrypoints=web,traefik_http_routers_lab1-static_middlewares=strip-lab1-prefix-file,traefik_http_routers_lab1-static_service=lab1,traefik_http_routers_lab1_rule_id=lab1,traefik_http_routers_lab1_priority=200,traefik_http_routers_lab1_entrypoints=web,traefik_http_routers_lab1_middlewares=lab1-auth-check-file__strip-lab1-prefix-file,traefik_http_routers_lab1_service=lab1,traefik_http_services_lab1_lb_port=8080"

gcloud run deploy lab-01-basic-magecart-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/01-basic-magecart:${IMAGE_TAG} \
  --region=${LABS_GAR_LOCATION} \
  --platform=managed \
  --project=${LABS_PROJECT_ID} \
  --allow-unauthenticated \
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
docker build \
  -f labs/02-dom-skimming/Dockerfile \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:latest \
  labs/02-dom-skimming || { echo "❌ Failed to build Lab 2 image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:latest

# Remove lab2-c2 route from main lab service (C2 is now separate)
TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab2-static_rule_id=lab2-static,traefik_http_routers_lab2-static_priority=250,traefik_http_routers_lab2-static_entrypoints=web,traefik_http_routers_lab2-static_middlewares=strip-lab2-prefix-file,traefik_http_routers_lab2-static_service=lab2-vulnerable-site,traefik_http_routers_lab2-main_rule_id=lab2,traefik_http_routers_lab2-main_priority=200,traefik_http_routers_lab2-main_entrypoints=web,traefik_http_routers_lab2-main_middlewares=lab2-auth-check-file__strip-lab2-prefix-file,traefik_http_services_lab2-vulnerable-site_lb_port=8080"

gcloud run deploy lab-02-dom-skimming-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/02-dom-skimming:${IMAGE_TAG} \
  --region=${LABS_GAR_LOCATION} \
  --platform=managed \
  --project=${LABS_PROJECT_ID} \
  --allow-unauthenticated \
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
docker build \
  -f labs/03-extension-hijacking/Dockerfile \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:latest \
  labs/03-extension-hijacking || { echo "❌ Failed to build Lab 3 image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:latest

# Remove lab3-extension route from main lab service (extension is now separate)
TRAEFIK_LABELS="traefik_enable=true,traefik_http_routers_lab3-static_rule_id=lab3-static,traefik_http_routers_lab3-static_priority=250,traefik_http_routers_lab3-static_entrypoints=web,traefik_http_routers_lab3-static_middlewares=strip-lab3-prefix-file,traefik_http_routers_lab3-static_service=lab3-vulnerable-site,traefik_http_routers_lab3-main_rule_id=lab3,traefik_http_routers_lab3-main_priority=200,traefik_http_routers_lab3-main_entrypoints=web,traefik_http_routers_lab3-main_middlewares=lab3-auth-check-file__strip-lab3-prefix-file,traefik_http_services_lab3-vulnerable-site_lb_port=8080"

gcloud run deploy lab-03-extension-hijacking-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/03-extension-hijacking:${IMAGE_TAG} \
  --region=${LABS_GAR_LOCATION} \
  --platform=managed \
  --project=${LABS_PROJECT_ID} \
  --allow-unauthenticated \
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
docker build \
  -f deploy/traefik/Dockerfile.cloudrun \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/traefik:${IMAGE_TAG} \
  -t ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/traefik:latest \
  deploy/traefik || { echo "❌ Failed to build Traefik image"; exit 1; }

docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/traefik:${IMAGE_TAG}
docker push ${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/traefik:latest

gcloud run deploy traefik-${ENVIRONMENT} \
  --image=${LABS_GAR_LOCATION}-docker.pkg.dev/${LABS_PROJECT_ID}/${LABS_REPOSITORY}/traefik:${IMAGE_TAG} \
  --region=${LABS_GAR_LOCATION} \
  --platform=managed \
  --project=${LABS_PROJECT_ID} \
  --allow-unauthenticated \
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
