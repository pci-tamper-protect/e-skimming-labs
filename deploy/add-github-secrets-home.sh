#!/bin/bash

# Add GitHub Secrets for E-Skimming Labs Home Repository
# This script pulls values from gcloud and adds them as GitHub repository secrets

set -e

# Configuration
REPO_OWNER="pci-tamper-protect"
REPO_NAME="e-skimming-labs"
PROJECT_ID="labs-home-prd"
REGION="us-central1"
REPOSITORY_NAME="e-skimming-labs-home"

echo "🔐 Adding GitHub Secrets for E-Skimming Labs Home"
echo "================================================="
echo "Repository: $REPO_OWNER/$REPO_NAME"
echo "Project: $PROJECT_ID"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first."
    echo "   Visit: https://cli.github.com/"
    exit 1
fi

# Check if gcloud CLI is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI (gcloud) is not installed. Please install it first."
    echo "   Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated with GitHub
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub. Please run: gh auth login"
    exit 1
fi

# Check if user is authenticated with Google Cloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Not authenticated with Google Cloud. Please run: gcloud auth login"
    exit 1
fi

# Set the correct project
echo "🔧 Setting Google Cloud project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Get the service account key for GitHub Actions
echo "🔑 Getting service account key..."
SERVICE_ACCOUNT_EMAIL="home-deploy-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Check if service account exists
if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL &> /dev/null; then
    echo "❌ Service account $SERVICE_ACCOUNT_EMAIL not found."
    echo "   Please run the Terraform deployment first."
    exit 1
fi

# Create a temporary key file
TEMP_KEY_FILE=$(mktemp)
echo "📝 Creating service account key..."

# Create the key
gcloud iam service-accounts keys create $TEMP_KEY_FILE \
    --iam-account=$SERVICE_ACCOUNT_EMAIL \
    --key-file-type=json

# Read the key content
SERVICE_ACCOUNT_KEY=$(cat $TEMP_KEY_FILE)

# Clean up the temporary file
rm $TEMP_KEY_FILE

echo "✅ Service account key retrieved"

# Add secrets to GitHub repository
echo ""
echo "🚀 Adding secrets to GitHub repository..."

# Add GCP_HOME_PROJECT_ID
echo "  - Adding GCP_HOME_PROJECT_ID..."
echo "$PROJECT_ID" | gh secret set GCP_HOME_PROJECT_ID --repo $REPO_OWNER/$REPO_NAME

# Add GCP_HOME_SA_KEY
echo "  - Adding GCP_HOME_SA_KEY..."
echo "$SERVICE_ACCOUNT_KEY" | gh secret set GCP_HOME_SA_KEY --repo $REPO_OWNER/$REPO_NAME

# Add GAR_HOME_LOCATION
echo "  - Adding GAR_HOME_LOCATION..."
echo "$REGION" | gh secret set GAR_HOME_LOCATION --repo $REPO_OWNER/$REPO_NAME

# Add REPOSITORY_HOME
echo "  - Adding REPOSITORY_HOME..."
echo "$REPOSITORY_NAME" | gh secret set REPOSITORY_HOME --repo $REPO_OWNER/$REPO_NAME

echo ""
echo "✅ All home secrets added successfully!"
echo ""
echo "📋 Added secrets:"
echo "  - GCP_HOME_PROJECT_ID: $PROJECT_ID"
echo "  - GCP_HOME_SA_KEY: [Service account key]"
echo "  - GAR_HOME_LOCATION: $REGION"
echo "  - REPOSITORY_HOME: $REPOSITORY_NAME"
echo ""
echo "🎉 GitHub Actions workflow can now deploy home components to Google Cloud!"
echo ""
echo "💡 Next steps:"
echo "  1. Push code to trigger the GitHub Actions workflow"
echo "  2. Monitor the deployment in the Actions tab"
echo "  3. Check Cloud Run services in the Google Cloud Console"
