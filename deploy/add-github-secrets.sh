#!/bin/bash

# Add GitHub Secrets for E-Skimming Labs
# This script adds all required secrets to the GitHub repository

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

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment configuration
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    print_error ".env file not found. Please create a symlink to .env.stg or .env.prd"
    print_info "Example: cd $SCRIPT_DIR && ln -s .env.prd .env"
    exit 1
fi

# Configuration
REPO="$GITHUB_REPO"

print_header "Adding GitHub Secrets to $REPO"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "gh CLI is required but not installed"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    print_error "Not authenticated to GitHub. Run: gh auth login"
    exit 1
fi

print_status "Authenticated to GitHub ✓"

# Add Project ID secrets
print_header "Adding Project ID Secrets for $ENVIRONMENT environment"
gh secret set GCP_HOME_PROJECT_ID --body "$HOME_PROJECT_ID" --repo $REPO
print_status "GCP_HOME_PROJECT_ID added ($HOME_PROJECT_ID) ✓"

gh secret set GCP_LABS_PROJECT_ID --body "$LABS_PROJECT_ID" --repo $REPO
print_status "GCP_LABS_PROJECT_ID added ($LABS_PROJECT_ID) ✓"

# Add Artifact Registry location secrets
print_header "Adding Artifact Registry Location Secrets"
gh secret set GAR_HOME_LOCATION --body "$HOME_REGION" --repo $REPO
print_status "GAR_HOME_LOCATION added ($HOME_REGION) ✓"

gh secret set GAR_LABS_LOCATION --body "$LABS_REGION" --repo $REPO
print_status "GAR_LABS_LOCATION added ($LABS_REGION) ✓"

# Add Repository name secrets
print_header "Adding Repository Name Secrets"
gh secret set REPOSITORY_HOME --body "$HOME_REPO" --repo $REPO
print_status "REPOSITORY_HOME added ($HOME_REPO) ✓"

gh secret set REPOSITORY_LABS --body "$LABS_REPO" --repo $REPO
print_status "REPOSITORY_LABS added ($LABS_REPO) ✓"

print_header "Verifying Secrets"

# List all secrets to verify
print_status "Current secrets in $REPO:"
gh secret list --repo $REPO

print_header "GitHub Secrets Setup Complete!"
print_info "All required configuration secrets have been added to the repository."
print_info "Service account keys (GCP_HOME_SA_KEY and GCP_LABS_SA_KEY) should already be set from the create-service-accounts script."
