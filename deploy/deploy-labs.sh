#!/bin/bash

# Deploy E-Skimming Labs Individual Labs Infrastructure
# This script deploys the Terraform infrastructure for the labs-prd project

set -e

PROJECT_ID="labs-prd"
REGION="us-central1"
TERRAFORM_DIR="terraform-labs"

echo "🧪 Deploying E-Skimming Labs Individual Labs Infrastructure"
echo "========================================================"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install it first."
    exit 1
fi

# Set the project
echo "📋 Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    firestore.googleapis.com \
    storage.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    servicenetworking.googleapis.com

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to terraform directory
cd "$SCRIPT_DIR/$TERRAFORM_DIR"

# Initialize Terraform
echo "🏗️  Initializing Terraform..."
terraform init

# Plan the deployment
echo "📋 Planning Terraform deployment..."
terraform plan \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -out=tfplan

# Ask for confirmation
echo ""
echo "⚠️  This will create the following resources in $PROJECT_ID:"
echo "   - Service accounts for labs runtime and GitHub Actions"
echo "   - Artifact Registry repository for lab images"
echo "   - Firestore database for lab analytics"
echo "   - Cloud Storage buckets for lab data and logs"
echo "   - Cloud Run services (Analytics)"
echo "   - Monitoring and logging"
echo ""

# Apply the plan
echo "🚀 Applying Terraform plan..."
terraform apply -auto-approve tfplan

echo ""
echo "✅ Labs infrastructure deployed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Get the service account key for GitHub Actions:"
echo "   terraform output -raw labs_deploy_key"
echo ""
echo "2. Add the following secrets to your GitHub repository:"
echo "   - GCP_LABS_PROJECT_ID: $PROJECT_ID"
echo "   - GCP_LABS_SA_KEY: [Use the service account key from step 1]"
echo "   - GAR_LABS_LOCATION: $REGION"
echo "   - REPOSITORY_LABS: e-skimming-labs"
echo ""
echo "3. Deploy the individual labs using GitHub Actions"
echo ""
echo "🔗 Useful outputs:"
terraform output
