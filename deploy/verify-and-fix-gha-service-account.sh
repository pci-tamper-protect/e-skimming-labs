#!/bin/bash
# Verify and fix GitHub Actions service account configuration
# This script checks if the correct service account is being used and provides instructions to fix it

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

print_info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Determine environment
ENVIRONMENT="${1:-stg}"
if [[ "$ENVIRONMENT" != "stg" && "$ENVIRONMENT" != "prd" ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be 'stg' or 'prd'"
    exit 1
fi

LABS_PROJECT_ID="labs-${ENVIRONMENT}"
HOME_PROJECT_ID="labs-home-${ENVIRONMENT}"

print_header "Verifying Service Account Configuration for $ENVIRONMENT"

# Expected service account names
LABS_SA_EMAIL="labs-deploy-sa@${LABS_PROJECT_ID}.iam.gserviceaccount.com"
HOME_SA_EMAIL="home-deploy-sa@${HOME_PROJECT_ID}.iam.gserviceaccount.com"

echo ""
print_info "Expected service accounts:"
echo "  Labs: $LABS_SA_EMAIL"
echo "  Home: $HOME_SA_EMAIL"

# Check if service accounts exist
echo ""
print_info "Checking if service accounts exist..."

if gcloud iam service-accounts describe "$LABS_SA_EMAIL" --project="$LABS_PROJECT_ID" &>/dev/null; then
    print_info "✅ Labs service account exists: $LABS_SA_EMAIL"
    
    # Check IAM roles
    echo ""
    print_info "Checking IAM roles for labs service account..."
    ROLES=$(gcloud projects get-iam-policy "$LABS_PROJECT_ID" \
        --flatten="bindings[].members" \
        --filter="bindings.members:serviceAccount:${LABS_SA_EMAIL}" \
        --format="value(bindings.role)" 2>/dev/null || echo "")
    
    if echo "$ROLES" | grep -q "artifactregistry.writer"; then
        print_info "✅ Has roles/artifactregistry.writer at project level"
    else
        print_warning "⚠️  Missing roles/artifactregistry.writer at project level"
    fi
    
    # Check repository-level IAM
    echo ""
    print_info "Checking repository-level IAM for e-skimming-labs repository..."
    REPO_IAM=$(gcloud artifacts repositories get-iam-policy e-skimming-labs \
        --location=us-central1 \
        --project="$LABS_PROJECT_ID" \
        --flatten="bindings[].members" \
        --filter="bindings.members:serviceAccount:${LABS_SA_EMAIL}" \
        --format="value(bindings.role)" 2>/dev/null || echo "")
    
    if echo "$REPO_IAM" | grep -q "artifactregistry.writer"; then
        print_info "✅ Has roles/artifactregistry.writer at repository level"
    else
        print_warning "⚠️  Missing roles/artifactregistry.writer at repository level"
        echo ""
        print_info "To fix, run Terraform apply or manually grant:"
        echo "  gcloud artifacts repositories add-iam-policy-binding e-skimming-labs \\"
        echo "    --location=us-central1 \\"
        echo "    --project=$LABS_PROJECT_ID \\"
        echo "    --member=serviceAccount:$LABS_SA_EMAIL \\"
        echo "    --role=roles/artifactregistry.writer"
    fi
else
    print_error "❌ Labs service account does not exist: $LABS_SA_EMAIL"
    echo ""
    print_info "Create it by running Terraform:"
    echo "  cd deploy/terraform-labs"
    echo "  terraform init -backend-config=backend-${ENVIRONMENT}.conf"
    echo "  terraform apply -var=\"environment=${ENVIRONMENT}\""
    exit 1
fi

if gcloud iam service-accounts describe "$HOME_SA_EMAIL" --project="$HOME_PROJECT_ID" &>/dev/null; then
    print_info "✅ Home service account exists: $HOME_SA_EMAIL"
else
    print_warning "⚠️  Home service account does not exist: $HOME_SA_EMAIL"
fi

# Instructions to update GitHub secret
echo ""
print_header "GitHub Secret Update Instructions"
echo ""
print_warning "The GitHub secret GCP_LABS_SA_KEY must contain the key for:"
echo "  $LABS_SA_EMAIL"
echo ""
print_info "To update the GitHub secret, run:"
echo ""
echo "1. Create a new service account key:"
echo "   gcloud iam service-accounts keys create /tmp/labs-deploy-key.json \\"
echo "     --iam-account=$LABS_SA_EMAIL \\"
echo "     --project=$LABS_PROJECT_ID"
echo ""
echo "2. Update the GitHub secret (base64 encoded):"
echo "   gh secret set GCP_LABS_SA_KEY --body \"\$(cat /tmp/labs-deploy-key.json | base64)\" \\"
echo "     --repo pci-tamper-protect/e-skimming-labs"
echo ""
echo "3. Clean up the key file:"
echo "   rm /tmp/labs-deploy-key.json"
echo ""
print_warning "⚠️  IMPORTANT: The old key file should be deleted after updating the secret!"
echo ""

# Verify current secret (if we can check it)
echo ""
print_header "Verification Steps"
echo ""
print_info "After updating the secret, verify:"
echo ""
echo "1. The service account has the correct permissions (checked above)"
echo ""
echo "2. The GitHub workflow uses the correct service account:"
echo "   - Check .github/workflows/deploy_labs.yml line 388"
echo "   - Should use: credentials_json: \${{ env.LABS_GCP_SA_KEY }}"
echo ""
echo "3. Test the deployment by triggering a workflow run"
echo ""

