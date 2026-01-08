#!/bin/bash

# Deploy E-Skimming Labs Individual Labs Infrastructure
# This script deploys the Terraform infrastructure for the labs project

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get repo root (one level up from deploy/)
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source environment configuration from repo root
# Check for .env file first (whether it's a file or symlink)
if [ -f "$REPO_ROOT/.env" ]; then
    # Determine which file .env points to for informative message
    if [ -L "$REPO_ROOT/.env" ]; then
        TARGET=$(readlink "$REPO_ROOT/.env")
        echo "📋 Using .env -> $TARGET"
    else
        echo "📋 Using .env"
    fi
    source "$REPO_ROOT/.env"
# Fallback to .env.prd or .env.stg if .env doesn't exist
elif [ -f "$REPO_ROOT/.env.prd" ]; then
    echo "📋 Using .env.prd from repo root (create symlink: ln -s .env.prd .env)"
    source "$REPO_ROOT/.env.prd"
elif [ -f "$REPO_ROOT/.env.stg" ]; then
    echo "📋 Using .env.stg from repo root (create symlink: ln -s .env.stg .env)"
    source "$REPO_ROOT/.env.stg"
else
    echo "❌ .env file not found in repo root: $REPO_ROOT"
    echo ""
    echo "Please create a .env file in the repo root with the following variables:"
    echo "  LABS_PROJECT_ID=labs-prd"
    echo "  LABS_REGION=us-central1"
    echo ""
    echo "You can either:"
    echo "  1. Create .env.prd or .env.stg in repo root with your values"
    echo "  2. Create a symlink in repo root: ln -s .env.prd .env (or ln -s .env.stg .env)"
    echo "  3. Or create .env directly in repo root"
    exit 1
fi

PROJECT_ID="$LABS_PROJECT_ID"
REGION="$LABS_REGION"
TERRAFORM_DIR="terraform-labs"

# Determine environment from project ID
if [[ "$PROJECT_ID" == *"-stg" ]]; then
    ENVIRONMENT="stg"
elif [[ "$PROJECT_ID" == *"-prd" ]]; then
    ENVIRONMENT="prd"
else
    echo "❌ Cannot determine environment from project ID: $PROJECT_ID"
    echo "   Project ID must end with -stg or -prd"
    echo "   Or set ENVIRONMENT environment variable explicitly (stg or prd)"
    exit 1
fi

# Verify environment is explicitly set
if [ -z "$ENVIRONMENT" ]; then
    echo "❌ ENVIRONMENT must be explicitly set (stg or prd)"
    echo "   Set it in .env file or as environment variable"
    exit 1
fi

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

# Check if user is authenticated with gcloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
    echo "❌ No active gcloud authentication found."
    echo "   Please run: gcloud auth login"
    exit 1
fi

# Check and set up Application Default Credentials (ADC) for Terraform
# Terraform uses ADC, which is separate from gcloud auth login
if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    # Check if ADC exists and is valid
    if ! gcloud auth application-default print-access-token &>/dev/null; then
        echo "⚠️  Application Default Credentials not found or expired."
        echo ""
        echo "📋 Terraform needs Application Default Credentials (ADC) to access GCS backend."
        echo "   This is separate from 'gcloud auth login'."
        echo ""
        echo "   Please run this command manually:"
        echo "   gcloud auth application-default login"
        echo ""
        echo "   Or if you prefer to use a service account key file:"
        echo "   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json"
        echo ""
        read -p "Press Enter after you've set up ADC, or Ctrl+C to cancel..."
        echo ""

        # Verify ADC is now working
        if ! gcloud auth application-default print-access-token &>/dev/null; then
            echo "❌ Application Default Credentials still not configured."
            echo "   Please run: gcloud auth application-default login"
            exit 1
        fi
        echo "✅ Application Default Credentials are now configured"
    else
        echo "✅ Application Default Credentials are configured"
    fi
else
    echo "✅ Using service account credentials from GOOGLE_APPLICATION_CREDENTIALS"
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install it first."
    exit 1
fi

# Set the project
echo "📋 Setting GCP project..."
gcloud config set project $PROJECT_ID

# Build and push Docker images before deploying services
if [ "${BUILD_IMAGES:-true}" != "false" ]; then
    echo "🏗️  Building Docker images..."
    "$SCRIPT_DIR/build-images.sh"
    echo ""
fi

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

# Navigate to terraform directory (relative to script location)
cd "$SCRIPT_DIR/$TERRAFORM_DIR"
TERRAFORM_DIR_ABS=$(pwd)

# Initialize Terraform with environment-specific backend config
echo "🏗️  Initializing Terraform..."
echo "   Directory: $TERRAFORM_DIR_ABS"
BACKEND_CONFIG="backend-${ENVIRONMENT}.conf"
if [ -f "$BACKEND_CONFIG" ]; then
    echo "   Running: terraform init -backend-config=\"$BACKEND_CONFIG\""
    terraform init -backend-config="$BACKEND_CONFIG"
else
    echo "❌ Backend config file not found: $BACKEND_CONFIG"
    echo "   Expected location: $SCRIPT_DIR/$TERRAFORM_DIR/$BACKEND_CONFIG"
    echo "   Please create backend config files: backend-prd.conf and backend-stg.conf"
    exit 1
fi

# Plan the deployment
echo "📋 Planning Terraform deployment..."
echo "   Directory: $TERRAFORM_DIR_ABS"
PLAN_CMD="terraform plan -var=\"environment=$ENVIRONMENT\" -var=\"deploy_services=true\" -out=tfplan"
echo "   Running: $PLAN_CMD"
terraform plan \
    -var="environment=$ENVIRONMENT" \
    -var="deploy_services=true" \
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
echo "   Directory: $TERRAFORM_DIR_ABS"
echo "   Running: terraform apply -auto-approve tfplan"
terraform apply -auto-approve tfplan || {
    echo ""
    echo "⚠️  If the error is about missing Docker images, make sure to run:"
    echo "   $SCRIPT_DIR/build-images.sh"
    echo ""
    exit 1
}

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
