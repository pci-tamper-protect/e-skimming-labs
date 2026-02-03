#!/bin/bash
# Import existing production resources into Terraform state
# This script imports all resources that already exist in production
#
# Usage:
#   ./import-prd.sh
#
# This will import:
#   - Service accounts (home-runtime-sa, home-deploy-sa, home-seo-sa, fbase-adm-sdk-runtime)
#   - Cloud Run services (home-seo-prd, home-index-prd)
#   - Artifact Registry repository (if exists)
#   - IAM bindings will be created automatically after service accounts are imported

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT="prd"
PROJECT_ID="labs-home-${ENVIRONMENT}"
REGION="us-central1"

echo -e "${GREEN}=== Importing Production Resources into Terraform State ===${NC}"
echo -e "${BLUE}Environment:${NC} ${ENVIRONMENT}"
echo -e "${BLUE}Project:${NC} ${PROJECT_ID}"
echo -e "${BLUE}Region:${NC} ${REGION}"
echo ""

cd "$(dirname "$0")"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
  echo -e "${YELLOW}🏗️  Initializing Terraform...${NC}"
  terraform init -reconfigure -backend-config="backend-${ENVIRONMENT}.conf"
fi

# Function to import a resource with error handling
import_resource() {
  local resource_type=$1
  local resource_name=$2
  local import_id=$3

  echo -e "${BLUE}📥 Importing ${resource_type}.${resource_name}...${NC}"
  if terraform import \
    -var="environment=${ENVIRONMENT}" \
    -var="deploy_services=true" \
    "${resource_type}.${resource_name}" \
    "${import_id}" 2>&1; then
    echo -e "${GREEN}   ✅ Successfully imported${NC}"
    return 0
  else
    echo -e "${YELLOW}   ⚠️  Failed to import (may already be in state)${NC}"
    return 1
  fi
}

# Import Service Accounts
echo -e "${GREEN}=== Importing Service Accounts ===${NC}"

SERVICE_ACCOUNTS=(
  "home_runtime:home-runtime-sa"
  "home_deploy:home-deploy-sa"
  "home_seo:home-seo-sa"
  "fbase_adm_sdk_runtime:fbase-adm-sdk-runtime"
)

for sa_pair in "${SERVICE_ACCOUNTS[@]}"; do
  IFS=':' read -r resource_name account_id <<< "$sa_pair"
  sa_email="${account_id}@${PROJECT_ID}.iam.gserviceaccount.com"

  # Check if service account exists
  if gcloud iam service-accounts describe "${sa_email}" \
    --project="${PROJECT_ID}" &>/dev/null; then
    import_resource "google_service_account" "${resource_name}" "projects/${PROJECT_ID}/serviceAccounts/${sa_email}"
  else
    echo -e "${YELLOW}   ⚠️  Service account ${account_id} does not exist, skipping${NC}"
  fi
done

echo ""

# Import Artifact Registry Repository
echo -e "${GREEN}=== Importing Artifact Registry Repository ===${NC}"
REPO_NAME="e-skimming-labs-home"
REPO_ID="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"

if gcloud artifacts repositories describe "${REPO_NAME}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" &>/dev/null; then
  import_resource "google_artifact_registry_repository" "home_repo" "${REPO_ID}"
else
  echo -e "${YELLOW}   ⚠️  Repository ${REPO_NAME} does not exist, skipping${NC}"
fi

echo ""

# Import Firestore Database (if exists)
echo -e "${GREEN}=== Importing Firestore Database ===${NC}"
if gcloud firestore databases describe --database="(default)" \
  --project="${PROJECT_ID}" &>/dev/null; then
  import_resource "google_firestore_database" "home_db" "${PROJECT_ID}/(default)"
else
  echo -e "${YELLOW}   ⚠️  Firestore database does not exist, skipping${NC}"
fi

echo ""

# Import Storage Bucket (if exists)
echo -e "${GREEN}=== Importing Storage Bucket ===${NC}"
BUCKET_NAME="${PROJECT_ID}-home-assets"
if gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
  import_resource "google_storage_bucket" "home_assets" "${BUCKET_NAME}"
else
  echo -e "${YELLOW}   ⚠️  Storage bucket ${BUCKET_NAME} does not exist, skipping${NC}"
fi

echo ""

# Import VPC Connector (if exists)
echo -e "${GREEN}=== Importing VPC Connector ===${NC}"
CONNECTOR_NAME="home-connector"
if gcloud compute networks vpc-access connectors describe "${CONNECTOR_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" &>/dev/null; then
  import_resource "google_vpc_access_connector" "home_connector" \
    "projects/${PROJECT_ID}/locations/${REGION}/connectors/${CONNECTOR_NAME}"
else
  echo -e "${YELLOW}   ⚠️  VPC connector ${CONNECTOR_NAME} does not exist, skipping${NC}"
fi

echo ""

# Import Cloud Run Services
echo -e "${GREEN}=== Importing Cloud Run Services ===${NC}"

# NOTE: Cloud Run services are NOT managed by Terraform
# They are deployed and managed by GitHub Actions workflows
# IAM bindings use data sources (see iap.tf) to reference services
# See TERRAFORM_SCOPE.md for architectural details
#
# If Cloud Run services are already in Terraform state, remove them:
#   ./remove-cloud-run-from-state.sh prd
#
# SERVICES=(
#   "home_seo_service[0]:home-seo-${ENVIRONMENT}"
#   "home_index_service[0]:home-index-${ENVIRONMENT}"
# )
#
# for service_pair in "${SERVICES[@]}"; do
#   IFS=':' read -r resource_name service_name <<< "$service_pair"
#
#   if gcloud run services describe "${service_name}" \
#     --region="${REGION}" \
#     --project="${PROJECT_ID}" &>/dev/null; then
#     import_resource "google_cloud_run_v2_service" "${resource_name}" \
#       "projects/${PROJECT_ID}/locations/${REGION}/services/${service_name}"
#   else
#     echo -e "${YELLOW}   ⚠️  Service ${service_name} does not exist, skipping${NC}"
#   fi
# done

echo ""
echo -e "${GREEN}=== Import Complete! ===${NC}"
echo ""
echo -e "${BLUE}💡 Next steps:${NC}"
echo "   1. Review the Terraform state: ${YELLOW}terraform state list${NC}"
echo "   2. Plan to see what Terraform wants to change:"
echo "      ${YELLOW}terraform plan -var=\"environment=${ENVIRONMENT}\" -var=\"deploy_services=true\"${NC}"
echo "   3. If the plan looks good, apply:"
echo "      ${YELLOW}terraform apply -var=\"environment=${ENVIRONMENT}\" -var=\"deploy_services=true\"${NC}"
echo ""
echo -e "${BLUE}📝 Note:${NC} IAM bindings will be created/updated automatically when you run terraform apply"
echo "   Service accounts must be imported before IAM bindings can be created"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC} If you get an error about Traefik service account not existing:"
echo "   1. Apply terraform-labs first to create the Traefik service account"
echo "   2. Then re-run terraform-home to create IAM bindings"
echo "   See: deploy/terraform-home/PRODUCTION_DEPLOYMENT.md for details"
