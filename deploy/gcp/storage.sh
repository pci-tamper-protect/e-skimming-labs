#!/bin/bash

# Create GCS bucket for E-Skimming Labs C2 Server storage
# Usage: ./storage.sh <prd|stg>
#
# This script creates the Cloud Storage bucket needed for the C2 server's
# smart aggregation storage adapter in Cloud Run deployments.

set -euo pipefail

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

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Usage information
usage() {
    echo "Usage: $0 <prd|stg>"
    echo ""
    echo "Create GCS bucket for E-Skimming Labs C2 Server storage"
    echo ""
    echo "Arguments:"
    echo "  prd    Deploy to production environment (labs-home-prd)"
    echo "  stg    Deploy to staging environment (labs-home-stg)"
    echo ""
    echo "Examples:"
    echo "  $0 prd    # Create production storage bucket"
    echo "  $0 stg    # Create staging storage bucket"
    exit 1
}

# Validate and load environment
load_environment() {
    local env="$1"
    local env_file="../.env.$env"

    if [[ ! -f "$env_file" ]]; then
        print_error "Environment file not found: $env_file"
        exit 1
    fi

    print_info "Loading environment configuration: $env_file"

    # Load environment variables
    set -a
    source "$env_file"
    set +a

    # Validate required variables
    if [[ -z "${HOME_PROJECT_ID:-}" ]]; then
        print_error "HOME_PROJECT_ID not set in $env_file"
        exit 1
    fi

    if [[ -z "${HOME_REGION:-}" ]]; then
        print_error "HOME_REGION not set in $env_file"
        exit 1
    fi

    print_success "Environment loaded: $env"
}

# Check requirements
check_requirements() {
    print_header "Checking Requirements"

    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is required but not installed"
        print_info "Install with: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi

    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 > /dev/null; then
        print_error "Not authenticated with gcloud"
        print_info "Run: gcloud auth login"
        exit 1
    fi

    print_success "All requirements met"
}

# Set GCP project context
set_project_context() {
    print_header "Setting GCP Project Context"

    print_info "Setting project to: $HOME_PROJECT_ID"
    gcloud config set project "$HOME_PROJECT_ID"

    print_info "Setting default region to: $HOME_REGION"
    gcloud config set compute/region "$HOME_REGION"

    print_success "Project context set"
}

# Create storage bucket
create_storage_bucket() {
    print_header "Creating C2 Server Storage Bucket"

    local bucket_name="e-skimming-labs-c2-data-${ENVIRONMENT}"
    local storage_class="STANDARD"
    local lifecycle_age="90" # Delete old batch files after 90 days

    print_info "Bucket name: $bucket_name"
    print_info "Location: $HOME_REGION"
    print_info "Storage class: $storage_class"

    # Create bucket if it doesn't exist
    if gsutil ls -b "gs://$bucket_name" >/dev/null 2>&1; then
        print_status "Bucket already exists: gs://$bucket_name"
    else
        print_info "Creating bucket: gs://$bucket_name"
        gsutil mb -p "$HOME_PROJECT_ID" -l "$HOME_REGION" -c "$storage_class" "gs://$bucket_name"
        print_success "Bucket created: gs://$bucket_name"
    fi

    # Set up lifecycle policy for automatic cleanup
    print_info "Setting up lifecycle policy (delete after $lifecycle_age days)"
    cat > /tmp/lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": $lifecycle_age,
          "matchesPrefix": ["batch/", "analysis/"]
        }
      }
    ]
  }
}
EOF

    gsutil lifecycle set /tmp/lifecycle.json "gs://$bucket_name"
    rm /tmp/lifecycle.json
    print_success "Lifecycle policy applied"

    # Enable uniform bucket-level access for better security
    print_info "Enabling uniform bucket-level access"
    gsutil uniformbucketlevelaccess set on "gs://$bucket_name"
    print_success "Uniform bucket-level access enabled"

    # Export bucket name for use in other scripts
    export C2_STORAGE_BUCKET="$bucket_name"
    echo "C2_STORAGE_BUCKET=$bucket_name" >> "../.env.$ENVIRONMENT"

    print_success "Storage bucket setup complete"
}

# Set up IAM permissions
setup_iam_permissions() {
    print_header "Setting Up IAM Permissions"

    local bucket_name="e-skimming-labs-c2-data-${ENVIRONMENT}"
    local service_account="github-actions@${HOME_PROJECT_ID}.iam.gserviceaccount.com"

    print_info "Granting permissions to service account: $service_account"

    # Grant Storage Object Admin role for the C2 server operations
    gsutil iam ch "serviceAccount:${service_account}:roles/storage.objectAdmin" "gs://$bucket_name"
    print_success "Granted Storage Object Admin role"

    # Grant Storage Legacy Bucket Reader for bucket metadata access
    gsutil iam ch "serviceAccount:${service_account}:roles/storage.legacyBucketReader" "gs://$bucket_name"
    print_success "Granted Legacy Bucket Reader role"

    print_success "IAM permissions configured"
}

# Verify bucket configuration
verify_bucket() {
    print_header "Verifying Bucket Configuration"

    local bucket_name="e-skimming-labs-c2-data-${ENVIRONMENT}"

    print_info "Bucket information:"
    gsutil ls -L -b "gs://$bucket_name" | grep -E "(Location|Storage class|Uniform bucket-level access)"

    print_info "Lifecycle configuration:"
    gsutil lifecycle get "gs://$bucket_name"

    print_success "Bucket verification complete"
}

# Main execution
main() {
    print_header "E-Skimming Labs C2 Storage Setup"

    # Validate arguments
    if [[ $# -lt 1 ]]; then
        print_error "Missing environment argument"
        usage
    fi

    local environment="$1"

    if [[ "$environment" != "prd" && "$environment" != "stg" ]]; then
        print_error "Invalid environment: $environment"
        usage
    fi

    # Execute setup steps
    load_environment "$environment"
    check_requirements
    set_project_context
    create_storage_bucket
    setup_iam_permissions
    verify_bucket

    # Success summary
    print_header "Setup Complete"
    print_success "C2 Server storage bucket created successfully"
    print_info "Bucket name: e-skimming-labs-c2-data-${ENVIRONMENT}"
    print_info "Project: $HOME_PROJECT_ID"
    print_info "Region: $HOME_REGION"
    print_info ""
    print_info "Environment variable added to .env.$ENVIRONMENT:"
    print_info "C2_STORAGE_BUCKET=e-skimming-labs-c2-data-${ENVIRONMENT}"
    print_info ""
    print_info "The C2 server will automatically use this bucket when deployed to Cloud Run."
}

# Execute main function with all arguments
main "$@"
