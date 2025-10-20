#!/bin/bash

# Add All GitHub Secrets for E-Skimming Labs
# This script adds secrets for both labs-prd and labs-home-prd projects

set -e

# Configuration
REPO_OWNER="pci-tamper-protect"
REPO_NAME="e-skimming-labs"

echo "🔐 Adding All GitHub Secrets for E-Skimming Labs"
echo "==============================================="
echo "Repository: $REPO_OWNER/$REPO_NAME"
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

# Function to add secrets for a project
add_project_secrets() {
    local PROJECT_ID=$1
    local PROJECT_TYPE=$2
    local REPOSITORY_NAME=$3
    
    echo ""
    echo "🔧 Processing $PROJECT_TYPE project: $PROJECT_ID"
    echo "----------------------------------------"
    
    # Set the correct project
    echo "Setting Google Cloud project to $PROJECT_ID..."
    gcloud config set project $PROJECT_ID
    
    # Get the service account key for GitHub Actions
    echo "Getting service account key..."
    SERVICE_ACCOUNT_EMAIL="${PROJECT_TYPE}-deploy-sa@$PROJECT_ID.iam.gserviceaccount.com"
    
    # Check if service account exists
    if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL &> /dev/null; then
        echo "❌ Service account $SERVICE_ACCOUNT_EMAIL not found."
        echo "   Please run the Terraform deployment first."
        return 1
    fi
    
    # Create a temporary key file
    TEMP_KEY_FILE=$(mktemp)
    echo "Creating service account key..."
    
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
    echo "Adding secrets to GitHub repository..."
    
    # Add project-specific secrets
    PROJECT_TYPE_UPPER=$(echo "$PROJECT_TYPE" | tr '[:lower:]' '[:upper:]')
    
    echo "  - Adding GCP_${PROJECT_TYPE_UPPER}_PROJECT_ID..."
    echo "$PROJECT_ID" | gh secret set "GCP_${PROJECT_TYPE_UPPER}_PROJECT_ID" --repo $REPO_OWNER/$REPO_NAME
    
    echo "  - Adding GCP_${PROJECT_TYPE_UPPER}_SA_KEY..."
    echo "$SERVICE_ACCOUNT_KEY" | gh secret set "GCP_${PROJECT_TYPE_UPPER}_SA_KEY" --repo $REPO_OWNER/$REPO_NAME
    
    echo "  - Adding GAR_${PROJECT_TYPE_UPPER}_LOCATION..."
    echo "us-central1" | gh secret set "GAR_${PROJECT_TYPE_UPPER}_LOCATION" --repo $REPO_OWNER/$REPO_NAME
    
    echo "  - Adding REPOSITORY_${PROJECT_TYPE_UPPER}..."
    echo "$REPOSITORY_NAME" | gh secret set "REPOSITORY_${PROJECT_TYPE_UPPER}" --repo $REPO_OWNER/$REPO_NAME
    
    echo "✅ $PROJECT_TYPE secrets added successfully!"
}

# Add secrets for both projects
add_project_secrets "labs-prd" "labs" "e-skimming-labs"
add_project_secrets "labs-home-prd" "home" "e-skimming-labs-home"

echo ""
echo "🎉 All secrets added successfully!"
echo ""
echo "📋 Summary of added secrets:"
echo ""
echo "Labs Project (labs-prd):"
echo "  - GCP_LABS_PROJECT_ID: labs-prd"
echo "  - GCP_LABS_SA_KEY: [Service account key]"
echo "  - GAR_LABS_LOCATION: us-central1"
echo "  - REPOSITORY_LABS: e-skimming-labs"
echo ""
echo "Home Project (labs-home-prd):"
echo "  - GCP_HOME_PROJECT_ID: labs-home-prd"
echo "  - GCP_HOME_SA_KEY: [Service account key]"
echo "  - GAR_HOME_LOCATION: us-central1"
echo "  - REPOSITORY_HOME: e-skimming-labs-home"
echo ""
echo "💡 Next steps:"
echo "  1. Push code to trigger the GitHub Actions workflow"
echo "  2. Monitor the deployment in the Actions tab"
echo "  3. Check Cloud Run services in both Google Cloud projects"
echo ""
echo "🔗 Useful links:"
echo "  - GitHub Actions: https://github.com/$REPO_OWNER/$REPO_NAME/actions"
echo "  - Labs Console: https://console.cloud.google.com/run?project=labs-prd"
echo "  - Home Console: https://console.cloud.google.com/run?project=labs-home-prd"
