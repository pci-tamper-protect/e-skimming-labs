#!/bin/bash

# Create Service Accounts for E-Skimming Labs
# This script creates service accounts for labs deployment and grants necessary permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${GREEN}=== $1 ===${NC}"
}

print_status() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

# Configuration
HOME_PROJECT_ID="labs-home-prd"
LABS_PROJECT_ID="labs-prd"
REGION="us-central1"
OPS_PROJECT_ID="pcioasis-operations"
CONTAINERS_REPO="containers"

# Check required tools
check_requirements() {
    print_header "Checking Requirements"

    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is required but not installed"
        exit 1
    fi

    print_status "All requirements met ✓"
}

# Authenticate with Google Cloud
authenticate_gcloud() {
    print_header "Authenticating with Google Cloud"

    gcloud auth login
    gcloud config set project $LABS_PROJECT_ID

    print_status "Google Cloud authentication complete ✓"
}

# Create GitHub Actions service account for Labs project
create_github_actions_sa() {
    print_header "Creating GitHub Actions Service Account"

    SA_NAME="github-actions"
    SA_EMAIL="$SA_NAME@$LABS_PROJECT_ID.iam.gserviceaccount.com"

    if gcloud iam service-accounts describe $SA_EMAIL --project=$LABS_PROJECT_ID &> /dev/null; then
        print_status "Service account $SA_EMAIL already exists ✓"
    else
        gcloud iam service-accounts create $SA_NAME \
            --display-name="GitHub Actions Service Account" \
            --description="Service account for GitHub Actions deployments in labs-prd" \
            --project=$LABS_PROJECT_ID

        print_status "Service account created ✓"
    fi

    # Grant necessary roles
    gcloud projects add-iam-policy-binding $LABS_PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/run.admin"

    gcloud projects add-iam-policy-binding $LABS_PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/artifactregistry.writer"

    gcloud projects add-iam-policy-binding $LABS_PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/iam.serviceAccountUser"

    print_status "Roles granted to GitHub Actions service account ✓"
}

# Create GitHub Actions service account for Home project
create_github_actions_home_sa() {
    print_header "Creating GitHub Actions Service Account for Home Project"

    SA_NAME="github-actions"
    SA_EMAIL="$SA_NAME@$HOME_PROJECT_ID.iam.gserviceaccount.com"

    if gcloud iam service-accounts describe $SA_EMAIL --project=$HOME_PROJECT_ID &> /dev/null; then
        print_status "Service account $SA_EMAIL already exists ✓"
    else
        gcloud iam service-accounts create $SA_NAME \
            --display-name="GitHub Actions Service Account" \
            --description="Service account for GitHub Actions deployments in labs-home-prd" \
            --project=$HOME_PROJECT_ID

        print_status "Service account created ✓"
    fi

    # Grant necessary roles
    gcloud projects add-iam-policy-binding $HOME_PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/run.admin"

    gcloud projects add-iam-policy-binding $HOME_PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/artifactregistry.writer"

    gcloud projects add-iam-policy-binding $HOME_PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/iam.serviceAccountUser"

    print_status "Roles granted to Home GitHub Actions service account ✓"
}

# Grant access to pull from operations Artifact Registry
grant_cross_project_access() {
    print_header "Granting Cross-Project Artifact Registry Access"

    LABS_SA_EMAIL="github-actions@$LABS_PROJECT_ID.iam.gserviceaccount.com"
    HOME_SA_EMAIL="github-actions@$HOME_PROJECT_ID.iam.gserviceaccount.com"

    print_status "Granting access for $LABS_SA_EMAIL..."

    # Grant at repository level
    gcloud artifacts repositories add-iam-policy-binding $CONTAINERS_REPO \
        --location=$REGION \
        --member="serviceAccount:$LABS_SA_EMAIL" \
        --role="roles/artifactregistry.reader" \
        --project=$OPS_PROJECT_ID || true

    # Grant at project level
    gcloud projects add-iam-policy-binding $OPS_PROJECT_ID \
        --member="serviceAccount:$LABS_SA_EMAIL" \
        --role="roles/artifactregistry.reader" || true

    print_status "Granting access for $HOME_SA_EMAIL..."

    # Grant access for home project service account
    gcloud artifacts repositories add-iam-policy-binding $CONTAINERS_REPO \
        --location=$REGION \
        --member="serviceAccount:$HOME_SA_EMAIL" \
        --role="roles/artifactregistry.reader" \
        --project=$OPS_PROJECT_ID || true

    gcloud projects add-iam-policy-binding $OPS_PROJECT_ID \
        --member="serviceAccount:$HOME_SA_EMAIL" \
        --role="roles/artifactregistry.reader" || true

    print_status "Cross-project access granted ✓"
}

# Create and download service account keys
create_service_account_keys() {
    print_header "Creating Service Account Keys"

    LABS_SA_EMAIL="github-actions@$LABS_PROJECT_ID.iam.gserviceaccount.com"
    HOME_SA_EMAIL="github-actions@$HOME_PROJECT_ID.iam.gserviceaccount.com"

    # Create labs service account key
    if [ ! -f deploy/labs-sa-key.json ]; then
        gcloud iam service-accounts keys create deploy/labs-sa-key.json \
            --iam-account=$LABS_SA_EMAIL \
            --project=$LABS_PROJECT_ID

        print_status "Labs service account key created ✓"
    else
        print_status "Labs service account key already exists ✓"
    fi

    # Create home service account key
    if [ ! -f deploy/home-sa-key.json ]; then
        gcloud iam service-accounts keys create deploy/home-sa-key.json \
            --iam-account=$HOME_SA_EMAIL \
            --project=$HOME_PROJECT_ID

        print_status "Home service account key created ✓"
    else
        print_status "Home service account key already exists ✓"
    fi
}

# Display summary
display_summary() {
    print_header "Setup Complete!"

    echo ""
    print_info "Service Accounts Created:"
    echo "  Labs: github-actions@$LABS_PROJECT_ID.iam.gserviceaccount.com"
    echo "  Home: github-actions@$HOME_PROJECT_ID.iam.gserviceaccount.com"

    echo ""
    print_info "Service Account Keys:"
    echo "  deploy/labs-sa-key.json"
    echo "  deploy/home-sa-key.json"

    echo ""
    print_info "Next Steps:"
    echo "  1. Add service account keys to GitHub secrets:"
    echo "     gh secret set GCP_LABS_SA_KEY --body \"\$(cat deploy/labs-sa-key.json | base64)\" --repo pci-tamper-protect/e-skimming-labs"
    echo "     gh secret set GCP_HOME_SA_KEY --body \"\$(cat deploy/home-sa-key.json | base64)\" --repo pci-tamper-protect/e-skimming-labs"
    echo ""
    echo "  2. Update GitHub workflow to use these service accounts"
    echo ""
    echo "  3. Clean up keys after adding to GitHub:"
    echo "     rm deploy/*-sa-key.json"
}

# Main execution
main() {
    print_header "Starting E-Skimming Labs Service Account Setup"

    check_requirements
    authenticate_gcloud
    create_github_actions_sa
    create_github_actions_home_sa
    grant_cross_project_access
    create_service_account_keys
    display_summary

    print_header "Service Account Setup Complete!"
}

# Run main function
main "$@"
