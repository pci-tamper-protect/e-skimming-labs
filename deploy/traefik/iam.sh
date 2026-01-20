#!/bin/bash
# Create and configure the traefik-provider-token-sa service account
# This SA is used by:
# 1. Local development (docker-compose.sidecar-local.yml)
# 2. GitHub Actions for running integration tests
#
# Usage:
#   ./deploy/traefik/iam.sh <stg|prd>
#
# The SA needs minimal permissions:
# - roles/run.viewer: List and describe Cloud Run services (route discovery)
# - roles/run.invoker: Invoke Cloud Run services (backend calls)
# - roles/iam.serviceAccountTokenCreator: Generate identity tokens for service-to-service auth
#
# This script is idempotent - safe to run multiple times.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PCIOASIS_OPS_DIR="$(cd "${REPO_ROOT}/../pcioasis-ops" && pwd 2>/dev/null || echo "")"

# Source credential check if available
if [ -f "$DEPLOY_DIR/check-credentials.sh" ]; then
    source "$DEPLOY_DIR/check-credentials.sh"
    if ! check_credentials; then
        echo ""
        echo "❌ Please fix credential issues first"
        exit 1
    fi
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Parse arguments
ENVIRONMENT="${1:-}"

if [[ ! "$ENVIRONMENT" =~ ^(stg|prd)$ ]]; then
    echo "Usage: $0 <stg|prd>"
    echo ""
    echo "Creates and configures traefik-provider-token-sa for the specified environment."
    echo "This script is idempotent - safe to run multiple times."
    exit 1
fi

# Configuration based on environment
SA_NAME="traefik-provider-token-sa"
SA_DISPLAY_NAME="Traefik Provider Token SA (local dev & CI)"

if [ "$ENVIRONMENT" = "prd" ]; then
    LABS_PROJECT="labs-prd"
    HOME_PROJECT="labs-home-prd"
else
    LABS_PROJECT="labs-stg"
    HOME_PROJECT="labs-home-stg"
fi

GITHUB_REPO="pci-tamper-protect/e-skimming-labs"
ENVIRONMENT_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
GITHUB_SECRET_NAME="TRAEFIK_PROVIDER_SA_KEY_${ENVIRONMENT_UPPER}"  # TRAEFIK_PROVIDER_SA_KEY_STG or _PRD

SA_EMAIL="${SA_NAME}@${LABS_PROJECT}.iam.gserviceaccount.com"

echo ""
echo "=========================================="
echo "Traefik Provider Token SA Setup"
echo "=========================================="
echo "Environment:    ${ENVIRONMENT}"
echo "Service Account: ${SA_EMAIL}"
echo "Labs Project:   ${LABS_PROJECT}"
echo "Home Project:   ${HOME_PROJECT}"
echo "GitHub Secret:  ${GITHUB_SECRET_NAME}"
echo "=========================================="
echo ""

# Step 1: Create service account if it doesn't exist
log_info "Checking if service account exists..."
if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${LABS_PROJECT}" > /dev/null 2>&1; then
    log_success "Service account already exists"
else
    log_info "Creating service account..."
    gcloud iam service-accounts create "${SA_NAME}" \
        --display-name="${SA_DISPLAY_NAME}" \
        --project="${LABS_PROJECT}"
    log_success "Service account created"
fi

echo ""

# Step 2: Grant permissions on labs project
log_info "Granting permissions on ${LABS_PROJECT}..."

# roles/run.viewer
gcloud projects add-iam-policy-binding "${LABS_PROJECT}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/run.viewer" \
    --condition=None \
    --quiet > /dev/null 2>&1 || true
log_success "  roles/run.viewer"

# roles/run.invoker
gcloud projects add-iam-policy-binding "${LABS_PROJECT}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/run.invoker" \
    --condition=None \
    --quiet > /dev/null 2>&1 || true
log_success "  roles/run.invoker"

echo ""

# Step 3: Grant permissions on home project
log_info "Granting permissions on ${HOME_PROJECT}..."

# roles/run.viewer
gcloud projects add-iam-policy-binding "${HOME_PROJECT}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/run.viewer" \
    --condition=None \
    --quiet > /dev/null 2>&1 || true
log_success "  roles/run.viewer"

# roles/run.invoker
gcloud projects add-iam-policy-binding "${HOME_PROJECT}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/run.invoker" \
    --condition=None \
    --quiet > /dev/null 2>&1 || true
log_success "  roles/run.invoker"

echo ""

# Step 4: Grant serviceAccountTokenCreator on self
log_info "Granting serviceAccountTokenCreator on self..."
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --project="${LABS_PROJECT}" \
    --quiet > /dev/null 2>&1 || true
log_success "  roles/iam.serviceAccountTokenCreator"

echo ""

# Step 5: Create key and upload to GitHub secrets
KEY_SCRIPT="${PCIOASIS_OPS_DIR}/secrets/create-service-account-key-and-update-env.sh"

if [ -f "${KEY_SCRIPT}" ]; then
    log_info "Creating key and uploading to GitHub secrets..."
    echo ""
    
    "${KEY_SCRIPT}" \
        "${SA_EMAIL}" \
        "${LABS_PROJECT}" \
        "${ENVIRONMENT}" \
        "${GITHUB_SECRET_NAME}" \
        --github-repo "${GITHUB_REPO}" \
        --use-dotenvx
    
    echo ""
    log_success "Key created and uploaded to GitHub"
else
    log_warning "pcioasis-ops not found, skipping key creation"
    echo ""
    echo "To create key manually:"
    echo "  gcloud iam service-accounts keys create ~/traefik-provider-token-sa-key.json \\"
    echo "    --iam-account=${SA_EMAIL} \\"
    echo "    --project=${LABS_PROJECT}"
    echo ""
    echo "  cat ~/traefik-provider-token-sa-key.json | base64 | gh secret set ${GITHUB_SECRET_NAME} --repo ${GITHUB_REPO}"
fi

echo ""
echo "=========================================="
log_success "Setup complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Service account: ${SA_EMAIL}"
echo "  ✓ roles/run.viewer on ${LABS_PROJECT}"
echo "  ✓ roles/run.invoker on ${LABS_PROJECT}"
echo "  ✓ roles/run.viewer on ${HOME_PROJECT}"
echo "  ✓ roles/run.invoker on ${HOME_PROJECT}"
echo "  ✓ roles/iam.serviceAccountTokenCreator (on self)"
if [ -f "${KEY_SCRIPT}" ]; then
    echo "  ✓ Key uploaded to GitHub secret: ${GITHUB_SECRET_NAME}"
fi
echo ""
echo "For local development:"
echo "  1. Create a local key:"
echo "     gcloud iam service-accounts keys create ~/traefik-provider-token-sa-key.json \\"
echo "       --iam-account=${SA_EMAIL} --project=${LABS_PROJECT}"
echo ""
echo "  2. Set environment variable:"
echo "     export GOOGLE_APPLICATION_CREDENTIALS=~/traefik-provider-token-sa-key.json"
echo ""
echo "  3. Or mount in docker-compose.sidecar-local.yml (see deploy/IAM_SETUP.md)"
