#!/bin/bash

# Fix Terraform State Bucket Permissions
# Grants necessary permissions to access the state bucket

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment configuration
if [ -f "$SCRIPT_DIR/.env" ]; then
    if [ -L "$SCRIPT_DIR/.env" ]; then
        TARGET=$(readlink "$SCRIPT_DIR/.env")
        echo "📋 Using .env -> $TARGET"
    fi
    source "$SCRIPT_DIR/.env"
elif [ -f "$SCRIPT_DIR/.env.prd" ]; then
    source "$SCRIPT_DIR/.env.prd"
elif [ -f "$SCRIPT_DIR/.env.stg" ]; then
    source "$SCRIPT_DIR/.env.stg"
else
    echo "❌ .env file not found"
    exit 1
fi

PROJECT_ID="${LABS_PROJECT_ID:-labs-prd}"
HOME_PROJECT_ID="${HOME_PROJECT_ID:-labs-home-prd}"

# Determine environment from project ID
if [[ "$PROJECT_ID" == *"-stg" ]]; then
    ENVIRONMENT="stg"
elif [[ "$PROJECT_ID" == *"-prd" ]]; then
    ENVIRONMENT="prd"
else
    ENVIRONMENT="${ENVIRONMENT:-prd}"
fi

BUCKET_NAME="e-skimming-labs-terraform-state-${ENVIRONMENT}"

# Service accounts for GitHub Actions
LABS_SA="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
HOME_SA="github-actions@${HOME_PROJECT_ID}.iam.gserviceaccount.com"

echo "🔐 Fixing Terraform State Bucket Permissions"
echo "============================================="
echo "Project ID: $PROJECT_ID"
echo "Home Project ID: $HOME_PROJECT_ID"
echo "Bucket: $BUCKET_NAME"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed."
    exit 1
fi

# Get current user email
CURRENT_USER=$(gcloud config get-value account 2>/dev/null || echo "")
if [ -z "$CURRENT_USER" ]; then
    echo "❌ No gcloud account found. Please run: gcloud auth login"
    exit 1
fi

echo "Current user: $CURRENT_USER"
echo ""

# Check if bucket exists
if ! gsutil ls -b "gs://$BUCKET_NAME" &>/dev/null; then
    echo "❌ Bucket $BUCKET_NAME does not exist."
    echo "   Please run: ./deploy/create-terraform-state-bucket.sh first"
    exit 1
fi

# Grant Storage Object Admin role to current user (needed for read/write state files)
echo "🔐 Granting storage.objectAdmin role to $CURRENT_USER..."
gsutil iam ch "user:$CURRENT_USER:roles/storage.objectAdmin" "gs://$BUCKET_NAME"

# Grant Storage Object Admin role to GitHub Actions service accounts
echo ""
echo "🔐 Granting storage.objectAdmin role to GitHub Actions service accounts..."
echo "  - $LABS_SA"
gsutil iam ch "serviceAccount:$LABS_SA:roles/storage.objectAdmin" "gs://$BUCKET_NAME" 2>/dev/null || \
    echo "    ⚠️  Service account may not exist yet (run create-service-accounts.sh first)"

echo "  - $HOME_SA"
gsutil iam ch "serviceAccount:$HOME_SA:roles/storage.objectAdmin" "gs://$BUCKET_NAME" 2>/dev/null || \
    echo "    ⚠️  Service account may not exist yet (run create-service-accounts.sh first)"

# Also grant Storage Admin at project level (for bucket management)
echo ""
echo "🔐 Granting storage.admin role at project level to current user..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$CURRENT_USER" \
    --role="roles/storage.admin" \
    --condition=None 2>/dev/null || \
    echo "    ⚠️  Role may already be granted"

echo ""
echo "✅ Permissions granted successfully!"
echo ""
echo "Granted permissions:"
echo "  ✅ User: $CURRENT_USER → storage.objectAdmin on bucket"
echo "  ✅ Service Account: $LABS_SA → storage.objectAdmin on bucket"
echo "  ✅ Service Account: $HOME_SA → storage.objectAdmin on bucket"
echo ""
echo "You should now be able to:"
echo "  - Read existing state files"
echo "  - Write new state files"
echo "  - Migrate local state to GCS"
echo "  - GitHub Actions can access state files"
echo ""
echo "Next steps:"
echo "1. Run: cd deploy/terraform && terraform init -migrate-state"
echo "   (This will migrate your local state to GCS)"
echo ""

