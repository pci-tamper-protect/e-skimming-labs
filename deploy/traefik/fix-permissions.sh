#!/bin/bash
# Grant Artifact Registry permissions to current user
# Usage: ./fix-permissions.sh [stg|prd] [user-email]

set -e

ENVIRONMENT="${1:-stg}"
REGION="us-central1"

if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="labs-prd"
else
  PROJECT_ID="labs-stg"
fi

REPOSITORY="e-skimming-labs"

# Get user email (from argument or current authenticated user)
if [ -n "${2:-}" ]; then
  USER_EMAIL="${2}"
else
  USER_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
  if [ -z "${USER_EMAIL}" ]; then
    echo "❌ No active gcloud authentication found"
    echo "   Run: gcloud auth login"
    echo "   Or provide user email as second argument: ./fix-permissions.sh ${ENVIRONMENT} user@example.com"
    exit 1
  fi
fi

echo "🔧 Granting Artifact Registry Permissions"
echo "   Project: ${PROJECT_ID}"
echo "   Repository: ${REPOSITORY}"
echo "   Region: ${REGION}"
echo "   User: ${USER_EMAIL}"
echo ""

# Check if repository exists
if ! gcloud artifacts repositories describe "${REPOSITORY}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" &>/dev/null; then
  echo "❌ Repository does not exist!"
  echo "   Creating repository..."
  gcloud artifacts repositories create "${REPOSITORY}" \
    --repository-format=docker \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --description="Docker images for e-skimming labs"
  echo "   ✅ Repository created"
fi

# Grant repository-level writer role
echo "📝 Granting repository-level writer role..."
gcloud artifacts repositories add-iam-policy-binding "${REPOSITORY}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --member="user:${USER_EMAIL}" \
  --role="roles/artifactregistry.writer"

echo "   ✅ Repository-level permissions granted"
echo ""

# Optionally grant project-level role (broader, but may be preferred)
read -p "Also grant project-level artifactregistry.writer role? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "📝 Granting project-level writer role..."
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="user:${USER_EMAIL}" \
    --role="roles/artifactregistry.writer"
  echo "   ✅ Project-level permissions granted"
fi

echo ""
echo "✅ Artifact Registry permissions granted!"
echo ""

# ── Cloud Run invoker permissions for Traefik routing ─────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Cloud Run service-to-service permissions"
echo "   These are required for Traefik to forward requests to private lab backends."
echo "   Use APPLY_PERMISSIONS.sh for a full IAM setup, or apply specific fixes below."
echo ""
echo "   To grant all Cloud Run invoker + viewer permissions in one step:"
echo "      ./deploy/traefik/APPLY_PERMISSIONS.sh ${ENVIRONMENT}"
echo ""
echo "   To verify current credential state:"
echo "      ./deploy/traefik/check-permissions.sh ${ENVIRONMENT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Next steps:"
echo "   1. Configure Docker authentication:"
echo "      gcloud auth configure-docker ${REGION}-docker.pkg.dev"
echo ""
echo "   2. Verify all permissions (AR + Cloud Run credentials):"
echo "      ./deploy/traefik/check-permissions.sh ${ENVIRONMENT}"
echo ""
echo "   3. Try pushing again:"
echo "      ./deploy-sidecar.sh ${ENVIRONMENT}"
