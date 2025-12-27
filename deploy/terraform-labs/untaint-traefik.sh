#!/bin/bash
# Remove taint from Traefik service and handle the missing image issue
# Usage: ./untaint-traefik.sh [stg|prd]

set -e

ENVIRONMENT="${1:-stg}"

echo "🔧 Fixing Traefik service taint issue..."
echo "   Environment: ${ENVIRONMENT}"
echo ""

# Step 1: Remove the taint
echo "1️⃣  Removing taint from Traefik service..."
echo "   Note: untaint doesn't accept -var flags, ensure you're in the correct directory"
terraform untaint google_cloud_run_v2_service.traefik[0] || {
  echo "   ⚠️  Resource might not be tainted, or doesn't exist in state"
}

echo ""
echo "2️⃣  Checking if Docker image exists..."
if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
else
  PROJECT_ID="labs-stg"
fi

IMAGE_NAME="us-central1-docker.pkg.dev/${PROJECT_ID}/e-skimming-labs/traefik:latest"

# Check if image exists
if gcloud artifacts docker images describe "${IMAGE_NAME}" > /dev/null 2>&1; then
  echo "   ✅ Docker image exists: ${IMAGE_NAME}"
  IMAGE_EXISTS=true
else
  echo "   ❌ Docker image does not exist: ${IMAGE_NAME}"
  IMAGE_EXISTS=false
fi

echo ""
if [ "$IMAGE_EXISTS" = false ]; then
  echo "3️⃣  Building and pushing Docker image..."
  echo "   This is required before Terraform can create the service"
  echo ""
  echo "   Run: cd ../traefik && ./build-and-push.sh ${ENVIRONMENT}"
  echo ""
  echo "   Or manually:"
  echo "   cd ../traefik"
  echo "   docker build -f Dockerfile.cloudrun -t ${IMAGE_NAME} ."
  echo "   docker push ${IMAGE_NAME}"
  echo ""
  echo "   After the image is pushed, run:"
  echo "   terraform apply -var=\"environment=${ENVIRONMENT}\""
else
  echo "3️⃣  Image exists. You can now run:"
  echo "   terraform plan -var=\"environment=${ENVIRONMENT}\""
  echo "   terraform apply -var=\"environment=${ENVIRONMENT}\""
fi

echo ""
echo "📝 Note: With ignore_changes = all, Terraform will:"
echo "   - Create the service resource in state (if it doesn't exist)"
echo "   - Not modify the service configuration (GitHub Actions manages it)"
echo "   - Only manage IAM bindings and domain mapping"
