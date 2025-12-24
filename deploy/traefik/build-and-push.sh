#!/bin/bash
# Build and push Traefik Docker image to Artifact Registry
# Usage: ./build-and-push.sh [stg|prd]

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
else
  PROJECT_ID="labs-stg"
fi

IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik"

echo "🔨 Building Traefik image for ${ENVIRONMENT}..."
echo "   Project: ${PROJECT_ID}"
echo "   Image: ${IMAGE_NAME}:latest"

# Authenticate to Artifact Registry
echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build the image
echo "🏗️  Building Docker image..."
cd "$(dirname "$0")"
docker build \
  -f Dockerfile.cloudrun \
  -t ${IMAGE_NAME}:latest \
  .

# Push the image
echo "📤 Pushing image to Artifact Registry..."
docker push ${IMAGE_NAME}:latest

echo "✅ Traefik image built and pushed successfully!"
echo "   Image: ${IMAGE_NAME}:latest"
echo ""
echo "You can now run: terraform apply"
