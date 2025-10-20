#!/bin/bash

# Deploy E-Skimming Labs Infrastructure
# This script deploys the Terraform infrastructure for the labs-prd project

set -e

PROJECT_ID="labs-prd"
REGION="us-central1"
TERRAFORM_DIR="terraform"

echo "🚀 Deploying E-Skimming Labs Infrastructure"
echo "=========================================="
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

# Navigate to terraform directory
cd $TERRAFORM_DIR

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
echo "⚠️  This will create the following resources:"
echo "   - Service accounts for labs and GitHub Actions"
echo "   - Artifact Registry repository"
echo "   - Firestore database"
echo "   - Cloud Storage buckets"
echo "   - Cloud Run services (analytics, SEO, index)"
echo "   - Monitoring and logging"
echo ""
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Apply the plan
    echo "🚀 Applying Terraform plan..."
    terraform apply tfplan
    
    echo ""
    echo "✅ Infrastructure deployed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Get the service account key for GitHub Actions:"
    echo "   terraform output -raw labs_deploy_key"
    echo ""
    echo "2. Add the following secrets to your GitHub repository:"
    echo "   - GCP_PROJECT_ID: $PROJECT_ID"
    echo "   - GCP_SA_KEY: [Use the service account key from step 1]"
    echo "   - GAR_LOCATION: $REGION"
    echo "   - REPOSITORY: e-skimming-labs"
    echo ""
    echo "3. Deploy the labs using GitHub Actions"
    echo ""
    echo "🔗 Useful outputs:"
    terraform output
else
    echo "❌ Deployment cancelled"
    exit 1
fi

