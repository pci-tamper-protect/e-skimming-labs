#!/bin/bash
# Deploy home-index-service to staging
# This script builds and deploys the service manually (alternative to GitHub Actions)

set -e

ENVIRONMENT="stg"
HOME_PROJECT_ID="labs-home-stg"
HOME_GAR_LOCATION="us-central1"
HOME_REPOSITORY="e-skimming-labs-home"
LABS_PROJECT_ID="labs-stg"
DOMAIN_PREFIX="labs.stg.pcioasis.com"

# Get the current git commit SHA (or use 'latest' tag)
IMAGE_TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"

echo "🚀 Deploying home-index-service to staging..."
echo "   Image tag: $IMAGE_TAG"
echo "   Project: $HOME_PROJECT_ID"
echo ""

# Authenticate to Artifact Registry
echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker ${HOME_GAR_LOCATION}-docker.pkg.dev

# Build the Docker image (from repo root, Dockerfile is in service directory)
echo "🏗️  Building Docker image..."
# Get the repo root (two levels up from this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

echo "   Script directory: $SCRIPT_DIR"
echo "   Repo root: $REPO_ROOT"
echo "   Dockerfile path: deploy/shared-components/home-index-service/Dockerfile"

# Verify Dockerfile exists
if [ ! -f "deploy/shared-components/home-index-service/Dockerfile" ]; then
  echo "❌ ERROR: Dockerfile not found at deploy/shared-components/home-index-service/Dockerfile"
  echo "   Current directory: $(pwd)"
  echo "   Looking for: $(pwd)/deploy/shared-components/home-index-service/Dockerfile"
  exit 1
fi

docker build \
  -f deploy/shared-components/home-index-service/Dockerfile \
  --build-arg ENVIRONMENT=$ENVIRONMENT \
  -t ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG} \
  -t ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:latest \
  .

# Push the image
echo "📤 Pushing image to Artifact Registry..."
docker push ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG}
docker push ${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:latest

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy home-index-${ENVIRONMENT} \
  --image=${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/index:${IMAGE_TAG} \
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
  --set-env-vars="HOME_PROJECT_ID=${HOME_PROJECT_ID},ENVIRONMENT=${ENVIRONMENT},DOMAIN=${DOMAIN_PREFIX},LABS_DOMAIN=${DOMAIN_PREFIX},MAIN_DOMAIN=pcioasis.com,LABS_PROJECT_ID=${LABS_PROJECT_ID},LAB1_URL=https://lab-01-basic-magecart-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app,LAB2_URL=https://lab-02-dom-skimming-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app/banking.html,LAB3_URL=https://lab-03-extension-hijacking-${ENVIRONMENT}-mmwwcfi5za-uc.a.run.app/index.html" \
  --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest \
  --labels="environment=${ENVIRONMENT},component=index,project=e-skimming-labs-home"

# Grant access to developer groups
echo "👥 Granting access to developer groups..."
gcloud run services add-iam-policy-binding home-index-${ENVIRONMENT} \
  --region=${HOME_GAR_LOCATION} \
  --project=${HOME_PROJECT_ID} \
  --member="group:2025-interns@pcioasis.com" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding home-index-${ENVIRONMENT} \
  --region=${HOME_GAR_LOCATION} \
  --project=${HOME_PROJECT_ID} \
  --member="group:core-eng@pcioasis.com" \
  --role="roles/run.invoker"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Service URL:"
gcloud run services describe home-index-${ENVIRONMENT} \
  --region=${HOME_GAR_LOCATION} \
  --project=${HOME_PROJECT_ID} \
  --format="value(status.url)"
