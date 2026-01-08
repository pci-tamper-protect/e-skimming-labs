#!/bin/bash
# Test script to deploy SEO service locally with corrected labels
# This tests the GCP label format fix before pushing to GitHub Actions

set -e

ENVIRONMENT="${1:-stg}"
REGION="${REGION:-us-central1}"

echo "🧪 Testing SEO service deployment with corrected labels"
echo "   Environment: ${ENVIRONMENT}"
echo "   Region: ${REGION}"
echo ""

# Load environment variables using dotenvx (if available)
# Don't source .env.stg directly as it contains encrypted values and special syntax
if [ -f ".env.${ENVIRONMENT}" ] && [ -f ".env.keys.${ENVIRONMENT}" ]; then
  if command -v dotenvx &> /dev/null; then
    echo "📋 Loading plaintext config from .env.${ENVIRONMENT} using dotenvx..."
    # Extract only plaintext config values (not encrypted secrets)
    # Use dotenvx to get plaintext values, filtering for config vars
    while IFS='=' read -r key value; do
      # Only export if it's a config variable (not encrypted)
      if [[ ! "$value" =~ ^encrypted: ]]; then
        export "$key=$value"
      fi
    done < <(dotenvx run -f ".env.${ENVIRONMENT}" -fk ".env.keys.${ENVIRONMENT}" -- env | grep -E '^(HOME_PROJECT_ID|HOME_REPOSITORY|HOME_GAR_LOCATION|LABS_PROJECT_ID)=' 2>/dev/null || true)
  else
    echo "⚠️  dotenvx not found, using defaults (can be overridden with env vars)"
  fi
else
  echo "ℹ️  Using default project IDs (override with env vars if needed)"
fi

# Set project IDs (adjust based on your setup)
if [ "$ENVIRONMENT" == "stg" ]; then
  HOME_PROJECT_ID="${HOME_PROJECT_ID:-labs-home-stg}"
  HOME_REPOSITORY="${HOME_REPOSITORY:-e-skimming-labs-home}"
  HOME_GAR_LOCATION="${HOME_GAR_LOCATION:-us-central1}"
  DOTENV_KEY="DOTENVX_KEY_STG"
  ALLOW_UNAUTH="--no-allow-unauthenticated"
else
  HOME_PROJECT_ID="${HOME_PROJECT_ID:-labs-home-prd}"
  HOME_REPOSITORY="${HOME_REPOSITORY:-e-skimming-labs-home}"
  HOME_GAR_LOCATION="${HOME_GAR_LOCATION:-us-central1}"
  DOTENV_KEY="DOTENVX_KEY_PRD"
  ALLOW_UNAUTH="--allow-unauthenticated"
fi

# Get the latest image tag (or use a specific one)
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_URI="${HOME_GAR_LOCATION}-docker.pkg.dev/${HOME_PROJECT_ID}/${HOME_REPOSITORY}/seo:${IMAGE_TAG}"

echo "📦 Image URI: ${IMAGE_URI}"
echo ""

# Check if image exists
if ! gcloud artifacts docker images describe "${IMAGE_URI}" --project="${HOME_PROJECT_ID}" &>/dev/null; then
  echo "⚠️  Warning: Image ${IMAGE_URI} not found"
  echo "   You may need to build and push the image first"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Test the labels string (this is what we're testing)
# Note: Traefik rule values use short identifiers (rule_id) to stay within GCP's 63 character limit
# The generate-routes-from-labels.sh script maps these identifiers to actual Traefik rules
LABELS="environment=${ENVIRONMENT},component=seo,project=e-skimming-labs-home,traefik_enable=true,traefik_http_routers_home-seo_rule_id=home-seo,traefik_http_routers_home-seo_priority=500,traefik_http_routers_home-seo_entrypoints=web,traefik_http_routers_home-seo_middlewares=strip-seo-prefix-file,traefik_http_services_home-seo_loadbalancer_server_port=8080"

echo "🏷️  Testing label format..."
echo "   Labels: ${LABELS}"
echo ""

# Validate label format (check for @ symbol which is not allowed)
if echo "$LABELS" | grep -q '@'; then
  echo "❌ ERROR: Labels contain '@' symbol which is not allowed in GCP labels"
  echo "   Found: $(echo "$LABELS" | grep -o '[^,]*@[^,]*')"
  exit 1
fi

echo "✅ Label format validation passed (no @ symbols found)"
echo ""

# Set gcloud project
echo "🔧 Setting gcloud project to ${HOME_PROJECT_ID}..."
gcloud config set project "${HOME_PROJECT_ID}"

# Validate label format before deploying
echo "🔍 Validating label format..."
if echo "$LABELS" | grep -q '@'; then
  echo "❌ ERROR: Labels contain '@' symbol which is not allowed in GCP labels"
  echo "   Found: $(echo "$LABELS" | grep -o '[^,]*@[^,]*')"
  exit 1
fi

echo "✅ Label format validation passed (no @ symbols found)"
echo ""
read -p "Deploy to Cloud Run? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled."
  exit 0
fi

echo ""
echo "🚀 Deploying..."
if gcloud run deploy "home-seo-${ENVIRONMENT}" \
  --image="${IMAGE_URI}" \
  --region="${HOME_GAR_LOCATION}" \
  --platform=managed \
  ${ALLOW_UNAUTH} \
  --service-account="home-runtime-sa@${HOME_PROJECT_ID}.iam.gserviceaccount.com" \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=5 \
  --set-env-vars="PROJECT_ID=${HOME_PROJECT_ID},HOME_PROJECT_ID=${HOME_PROJECT_ID},ENVIRONMENT=${ENVIRONMENT},MAIN_DOMAIN=pcioasis.com,LABS_DOMAIN=${ENVIRONMENT}.pcioasis.com,LABS_PROJECT_ID=labs-${ENVIRONMENT}" \
  --update-secrets="/etc/secrets/dotenvx-key=${DOTENV_KEY}:latest" \
  --labels="${LABELS}"; then
  echo ""
  echo "✅ Deployment complete!"
else
  echo ""
  echo "❌ Deployment failed. Check the error above."
  exit 1
fi
