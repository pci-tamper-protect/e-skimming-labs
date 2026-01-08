#!/bin/bash
# Remove Cloud Run services from Terraform state
# This does NOT destroy the services - they continue to run
# Cloud Run services are managed by GitHub Actions, NOT Terraform
# See TERRAFORM_SCOPE.md for details

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENVIRONMENT="${1:-stg}"

echo "⚠️  Removing Cloud Run services from Terraform state..."
echo "   This does NOT destroy the services - they will continue running"
echo "   Environment: ${ENVIRONMENT}"
echo ""

# Remove Cloud Run services from state
# These services are managed by GitHub Actions, not Terraform
# Note: terraform state rm doesn't accept -var flags, but we need to be in the right backend
echo "Removing home-seo-${ENVIRONMENT} from state..."
terraform state rm \
  google_cloud_run_v2_service.home_seo_service[0] 2>&1 || echo "  (not in state or already removed)"

echo "Removing home-index-${ENVIRONMENT} from state..."
terraform state rm \
  google_cloud_run_v2_service.home_index_service[0] 2>&1 || echo "  (not in state or already removed)"

echo ""
echo "✅ Cloud Run services removed from Terraform state"
echo "   Services continue running and are managed by GitHub Actions"
echo ""
echo "Next steps:"
echo "  1. Verify services are still running: gcloud run services list --project=labs-home-${ENVIRONMENT}"
echo "  2. Run terraform plan to verify state is clean"
echo "  3. IAM bindings will continue to work via data sources in iap.tf"
