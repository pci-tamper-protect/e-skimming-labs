#!/bin/bash
# Import existing production resources into Terraform state
# Similar to import-existing-resources.sh but specifically for production

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENVIRONMENT="${1:-prd}"
REGION="${2:-us-central1}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID="labs-${ENVIRONMENT}"

echo -e "${BLUE}=== Importing Production Resources ===${NC}"
echo -e "${BLUE}Environment:${NC} ${ENVIRONMENT}"
echo -e "${BLUE}Project:${NC} ${PROJECT_ID}"
echo -e "${BLUE}Region:${NC} ${REGION}"
echo ""

# Initialize Terraform with production backend
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init -reconfigure -backend-config=backend-${ENVIRONMENT}.conf >/dev/null 2>&1 || {
    echo -e "${RED}Failed to initialize Terraform${NC}"
    exit 1
}

# Helper function to import a resource with error handling
import_resource() {
    local resource_type=$1
    local resource_name=$2
    local import_id=$3

    if terraform state show "${resource_name}" >/dev/null 2>&1; then
        echo -e "${YELLOW}   ⚠️  ${resource_name} already in state, skipping${NC}"
        return 0
    fi

    echo -e "${BLUE}   Importing ${resource_name}...${NC}"
    if terraform import "${resource_name}" "${import_id}" 2>&1; then
        echo -e "${GREEN}   ✅ Imported: ${resource_name}${NC}"
        return 0
    else
        echo -e "${YELLOW}   ⚠️  Failed to import ${resource_name} (may not exist)${NC}"
        return 1
    fi
}

# Service Accounts
echo -e "${BLUE}=== Service Accounts ===${NC}"
SERVICE_ACCOUNTS=(
    "google_service_account.labs_runtime:labs-runtime-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    "google_service_account.labs_deploy:labs-deploy-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    "google_service_account.labs_analytics:labs-analytics-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    "google_service_account.labs_seo:labs-seo-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    "google_service_account.traefik:traefik-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com"
)

for sa_pair in "${SERVICE_ACCOUNTS[@]}"; do
    IFS=':' read -r resource_name sa_email <<< "$sa_pair"
    import_resource "service_account" "${resource_name}" "projects/${PROJECT_ID}/serviceAccounts/${sa_email}"
done

# Artifact Registry
echo ""
echo -e "${BLUE}=== Artifact Registry ===${NC}"
import_resource "artifact_registry_repository" "google_artifact_registry_repository.labs_repo" \
    "projects/${PROJECT_ID}/locations/${REGION}/repositories/e-skimming-labs"

# Firestore Database
echo ""
echo -e "${BLUE}=== Firestore ===${NC}"
import_resource "firestore_database" "google_firestore_database.labs_db" \
    "projects/${PROJECT_ID}/databases/(default)"

# Firestore Indexes
# Note: Firestore indexes have complex IDs - we need to query them first
echo -e "${BLUE}   Checking Firestore indexes...${NC}"
# Try to import indexes - if they fail, they may not exist or have different IDs
# Firestore index import format: projects/{project}/databases/{database}/collectionGroups/{collection}/indexes/{index_id}
# The index_id is auto-generated, so we need to list them first

echo -e "${YELLOW}   ⚠️  Firestore indexes have auto-generated IDs${NC}"
echo -e "${YELLOW}   ⚠️  If you get 'index already exists' errors, the indexes are already created${NC}"
echo -e "${YELLOW}   ⚠️  You may need to list indexes and import manually:${NC}"
echo -e "${YELLOW}      gcloud firestore indexes list --project=${PROJECT_ID}${NC}"
echo -e "${YELLOW}   ⚠️  Or skip index creation in firestore.tf temporarily${NC}"

# Storage Buckets
echo ""
echo -e "${BLUE}=== Storage Buckets ===${NC}"
import_resource "storage_bucket" "google_storage_bucket.labs_data" \
    "${PROJECT_ID}-labs-data"

import_resource "storage_bucket" "google_storage_bucket.labs_logs" \
    "${PROJECT_ID}-labs-logs"

# VPC Connector
echo ""
echo -e "${BLUE}=== VPC Connector ===${NC}"
import_resource "vpc_access_connector" "google_vpc_access_connector.labs_connector" \
    "projects/${PROJECT_ID}/locations/${REGION}/connectors/labs-connector"

# Cloud Run Services - NOT imported (managed by GitHub Actions, not Terraform)
# See TERRAFORM_SCOPE.md for architectural details
echo ""
echo -e "${BLUE}=== Cloud Run Services ===${NC}"
echo -e "${YELLOW}   ⚠️  Cloud Run services are NOT managed by Terraform${NC}"
echo -e "${YELLOW}   ⚠️  They are deployed and managed by GitHub Actions workflows${NC}"
echo -e "${YELLOW}   ⚠️  IAM bindings use data sources to reference services${NC}"
echo -e "${YELLOW}   ⚠️  If services are in state, remove them: ./remove-cloud-run-from-state.sh ${ENVIRONMENT}${NC}"
echo ""
echo -e "${BLUE}=== Service Account Keys ===${NC}"
echo -e "${YELLOW}   ⚠️  Service account keys are NOT managed by Terraform${NC}"
echo -e "${YELLOW}   ⚠️  They are created via gcloud commands and scripts${NC}"
echo -e "${YELLOW}   ⚠️  If keys are in state, remove them: ./remove-cloud-run-from-state.sh ${ENVIRONMENT}${NC}"

# Traefik Domain Mapping (if exists)
echo ""
echo -e "${BLUE}=== Traefik Domain Mapping ===${NC}"
if gcloud run domain-mappings describe traefik \
    --region="${REGION}" \
    --project="${PROJECT_ID}" &>/dev/null; then
    import_resource "cloud_run_domain_mapping" "google_cloud_run_domain_mapping.traefik_domain" \
        "projects/${PROJECT_ID}/locations/${REGION}/domainmappings/traefik"
else
    echo -e "${YELLOW}   ⚠️  Traefik domain mapping does not exist, skipping${NC}"
fi

echo ""
echo -e "${GREEN}=== Import Complete! ===${NC}"
echo ""
echo -e "${BLUE}💡 Next steps:${NC}"
echo "   1. If Firestore indexes exist, you may need to:"
echo "      a. List existing indexes: ${YELLOW}gcloud firestore indexes list --project=${PROJECT_ID}${NC}"
echo "      b. Import them manually with their auto-generated IDs"
echo "      c. Or temporarily comment out index resources in firestore.tf"
echo "   2. Review the Terraform state: ${YELLOW}terraform state list${NC}"
echo "   3. Plan to see what Terraform wants to change:"
echo "      ${YELLOW}terraform plan -var=\"environment=${ENVIRONMENT}\" -var=\"deploy_services=true\"${NC}"
echo "   4. If the plan looks good, apply:"
echo "      ${YELLOW}terraform apply -var=\"environment=${ENVIRONMENT}\" -var=\"deploy_services=true\"${NC}"
echo ""
echo -e "${BLUE}📝 Note:${NC} IAM bindings will be created/updated automatically when you run terraform apply"
echo "   Service accounts must be imported before IAM bindings can be created"
