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

# Setup plugin first (copy plugin source to plugins-local directory)
echo "🔧 Setting up Traefik Cloud Run plugin..."
cd "$(dirname "$0")"
./setup-plugin.sh || {
    echo "❌ ERROR: Failed to setup plugin. Make sure traefik-cloudrun-provider is a sibling directory."
    exit 1
}
echo ""

# Authenticate to Artifact Registry
echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build the image
echo "🏗️  Building Docker image..."
docker build \
  -f Dockerfile.cloudrun \
  -t ${IMAGE_NAME}:latest \
  .

# Push the image
echo "📤 Pushing image to Artifact Registry..."
docker push ${IMAGE_NAME}:latest

echo "✅ Traefik image built and pushed successfully!"
echo "   Image: ${IMAGE_NAME}:latest"
