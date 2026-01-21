#!/bin/bash
# Check Artifact Registry permissions for current user
# Usage: ./check-permissions.sh [stg|prd]

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
else
  PROJECT_ID="labs-stg"
fi

REPOSITORY="e-skimming-labs"

echo "🔍 Checking Artifact Registry Permissions"
echo "   Project: ${PROJECT_ID}"
echo "   Repository: ${REPOSITORY}"
echo "   Region: ${REGION}"
echo ""

# Get current authenticated user
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
if [ -z "${CURRENT_USER}" ]; then
  echo "❌ No active gcloud authentication found"
  echo "   Run: gcloud auth login"
  exit 1
fi

echo "👤 Current authenticated user: ${CURRENT_USER}"
echo ""

# Check if repository exists
echo "📦 Checking if repository exists..."
if gcloud artifacts repositories describe "${REPOSITORY}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" &>/dev/null; then
  echo "   ✅ Repository exists"
else
  echo "   ❌ Repository does not exist!"
  echo "   Create it with:"
  echo "   gcloud artifacts repositories create ${REPOSITORY} \\"
  echo "     --repository-format=docker \\"
  echo "     --location=${REGION} \\"
  echo "     --project=${PROJECT_ID}"
  exit 1
fi

# Check IAM permissions on repository
echo ""
echo "🔐 Checking IAM permissions on repository..."
echo ""

# Check if user has writer role
if gcloud artifacts repositories get-iam-policy "${REPOSITORY}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(bindings)" 2>/dev/null | grep -q "${CURRENT_USER}"; then
  echo "   ✅ User found in IAM policy"
  gcloud artifacts repositories get-iam-policy "${REPOSITORY}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --format="table(bindings.role,bindings.members)" | grep -A 10 "${CURRENT_USER}" || true
else
  echo "   ❌ User NOT found in repository IAM policy"
fi

# Check project-level permissions
echo ""
echo "🔐 Checking project-level IAM permissions..."
PROJECT_ROLES=$(gcloud projects get-iam-policy "${PROJECT_ID}" \
  --flatten="bindings[].members" \
  --filter="bindings.members:${CURRENT_USER}" \
  --format="value(bindings.role)" 2>/dev/null || echo "")

if [ -n "${PROJECT_ROLES}" ]; then
  echo "   ✅ User has project-level roles:"
  echo "${PROJECT_ROLES}" | sed 's/^/      - /'
  
  # Check for artifactregistry.writer
  if echo "${PROJECT_ROLES}" | grep -q "artifactregistry.writer\|artifactregistry.admin"; then
    echo "   ✅ User has Artifact Registry writer permissions at project level"
  else
    echo "   ⚠️  User does NOT have artifactregistry.writer at project level"
  fi
else
  echo "   ❌ User has no project-level roles"
fi

# Check Docker authentication
echo ""
echo "🐳 Checking Docker authentication..."
if docker pull "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/test:latest" &>/dev/null 2>&1; then
  echo "   ✅ Docker can authenticate (read test)"
else
  echo "   ⚠️  Docker authentication may not be configured"
  echo "   Run: gcloud auth configure-docker ${REGION}-docker.pkg.dev"
fi

echo ""
echo "💡 To grant permissions, run:"
echo ""
echo "   # Grant repository-level writer role:"
echo "   gcloud artifacts repositories add-iam-policy-binding ${REPOSITORY} \\"
echo "     --location=${REGION} \\"
echo "     --project=${PROJECT_ID} \\"
echo "     --member=\"user:${CURRENT_USER}\" \\"
echo "     --role=\"roles/artifactregistry.writer\""
echo ""
echo "   # OR grant project-level role (broader):"
echo "   gcloud projects add-iam-policy-binding ${PROJECT_ID} \\"
echo "     --member=\"user:${CURRENT_USER}\" \\"
echo "     --role=\"roles/artifactregistry.writer\""
echo ""
