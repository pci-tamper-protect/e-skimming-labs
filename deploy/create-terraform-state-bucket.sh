#!/bin/bash

# Create Terraform State Bucket
# This bucket must exist before running terraform init
# It stores the Terraform state files for all e-skimming-labs infrastructure

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment configuration
# Check for .env file first (whether it's a file or symlink)
if [ -f "$SCRIPT_DIR/.env" ]; then
    # Determine which file .env points to for informative message
    if [ -L "$SCRIPT_DIR/.env" ]; then
        TARGET=$(readlink "$SCRIPT_DIR/.env")
        echo "📋 Using .env -> $TARGET"
    else
        echo "📋 Using .env"
    fi
    source "$SCRIPT_DIR/.env"
# Fallback to .env.prd or .env.stg if .env doesn't exist
elif [ -f "$SCRIPT_DIR/.env.prd" ]; then
    echo "📋 Using .env.prd (create symlink: ln -s .env.prd .env)"
    source "$SCRIPT_DIR/.env.prd"
elif [ -f "$SCRIPT_DIR/.env.stg" ]; then
    echo "📋 Using .env.stg (create symlink: ln -s .env.stg .env)"
    source "$SCRIPT_DIR/.env.stg"
else
    echo "❌ .env file not found in $SCRIPT_DIR"
    echo ""
    echo "Please create a .env file with the following variables:"
    echo "  LABS_PROJECT_ID=labs-prd (or labs-stg)"
    echo "  LABS_REGION=us-central1"
    echo ""
    exit 1
fi

# Use labs project for the state bucket (environment-specific)
PROJECT_ID="${LABS_PROJECT_ID:-labs-prd}"
HOME_PROJECT_ID="${HOME_PROJECT_ID:-labs-home-prd}"
REGION="${LABS_REGION:-us-central1}"

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

echo "🪣 Creating Terraform State Bucket"
echo "=================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Bucket: $BUCKET_NAME"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Set the project
echo "📋 Setting GCP project..."
gcloud config set project $PROJECT_ID

# Check if bucket already exists
if gsutil ls -b "gs://$BUCKET_NAME" &>/dev/null; then
    echo "✅ Bucket $BUCKET_NAME already exists"
    echo ""
    echo "Bucket details:"
    gsutil ls -L "gs://$BUCKET_NAME" | head -10
    exit 0
fi

# Create the bucket
echo "🪣 Creating bucket $BUCKET_NAME..."
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION "gs://$BUCKET_NAME"

# Enable versioning (important for state files)
echo "📝 Enabling versioning..."
gsutil versioning set on "gs://$BUCKET_NAME"

# Enable uniform bucket-level access
echo "🔒 Enabling uniform bucket-level access..."
gsutil uniformbucketlevelaccess set on "gs://$BUCKET_NAME"

# Set lifecycle policy (optional - keep state files indefinitely)
echo "📋 Setting lifecycle policy..."
cat > /tmp/state-bucket-lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "numNewerVersions": 10
        }
      }
    ]
  }
}
EOF
gsutil lifecycle set /tmp/state-bucket-lifecycle.json "gs://$BUCKET_NAME"
rm /tmp/state-bucket-lifecycle.json

echo ""
echo "✅ Terraform state bucket created successfully!"
echo ""
echo "Bucket: gs://$BUCKET_NAME"
echo "Location: $REGION"
echo "Versioning: Enabled"
echo "Uniform bucket-level access: Enabled"
echo ""

# Grant permissions to GitHub Actions service accounts (if they exist)
echo "🔐 Granting permissions to GitHub Actions service accounts..."
if gcloud iam service-accounts describe "$LABS_SA" --project="$PROJECT_ID" &>/dev/null; then
    echo "  ✅ Granting access to $LABS_SA..."
    gsutil iam ch "serviceAccount:$LABS_SA:roles/storage.objectAdmin" "gs://$BUCKET_NAME"
else
    echo "  ⚠️  $LABS_SA not found (run create-service-accounts.sh first)"
fi

if gcloud iam service-accounts describe "$HOME_SA" --project="$HOME_PROJECT_ID" &>/dev/null; then
    echo "  ✅ Granting access to $HOME_SA..."
    gsutil iam ch "serviceAccount:$HOME_SA:roles/storage.objectAdmin" "gs://$BUCKET_NAME"
else
    echo "  ⚠️  $HOME_SA not found (run create-service-accounts.sh first)"
fi

echo ""
echo "📋 Next steps:"
echo "1. Grant permissions to your user account:"
echo "   ./deploy/fix-terraform-state-permissions.sh"
echo ""
echo "2. Now you can run terraform init:"
echo "   cd deploy/terraform"
echo "   terraform init"
echo ""

