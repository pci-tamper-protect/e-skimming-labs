#!/bin/bash
# Create or rotate service account key and update .env files
#
# This is a wrapper script that calls the general-purpose script in pcioasis-ops/secrets
# to create or rotate a service account key and update .env files.
#
# IMPORTANT: Service Account Management Separation
# - Terraform: Manages service accounts and IAM bindings (infrastructure)
# - gcloud: Manages service account keys (credentials)
#
# Usage:
#   ./create-or-rotate-service-account-key.sh <service-account-email> <environment> [--quiet]
#
# Examples:
#   ./create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg
#   ./create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-prd.iam.gserviceaccount.com prd
#   ./create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg --quiet
#
# Prerequisites:
#   - Service account must exist (created by Terraform)
#   - Run: cd deploy/terraform-home && terraform apply

set -euo pipefail

set -x
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up 2 levels from deploy/secrets to get repo root
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Path to pcioasis-ops/secrets (sibling directory)
OPS_SECRETS_DIR="${REPO_ROOT}/../pcioasis-ops/secrets"
GENERAL_SCRIPT="${OPS_SECRETS_DIR}/create-service-account-key-and-update-env.sh"

# Parse arguments
QUIET=false
SERVICE_ACCOUNT_EMAIL=""
ENVIRONMENT=""
GITHUB_SECRET_NAME=""

for arg in "$@"; do
    if [ "$arg" = "--quiet" ]; then
        QUIET=true
    elif [[ "$arg" == *"@"* ]] && [ -z "$SERVICE_ACCOUNT_EMAIL" ]; then
        SERVICE_ACCOUNT_EMAIL="$arg"
    elif [[ "$arg" =~ ^(stg|prd)$ ]] && [ -z "$ENVIRONMENT" ]; then
        ENVIRONMENT="$arg"
    elif [[ "$arg" == *"@"* ]] && [ -z "$GITHUB_SECRET_NAME" ]; then
        GITHUB_SECRET_NAME="$arg"
    fi
done

# Check if required arguments are provided
if [ -z "$SERVICE_ACCOUNT_EMAIL" ] || [ -z "$ENVIRONMENT" ]; then
    echo -e "${RED}Usage: $0 <service-account-email> <environment> [--quiet]${NC}" >&2
    echo "" >&2
    echo "Arguments:" >&2
    echo "  service-account-email  Full service account email (required)" >&2
    echo "  environment          Environment: stg or prd (required)" >&2
    echo "  --quiet             Optional: Auto-rotate if key exists (no prompt)" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg" >&2
    echo "  $0 fbase-adm-sdk-runtime@labs-home-prd.iam.gserviceaccount.com prd" >&2
    echo "  $0 fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg --quiet" >&2
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(stg|prd)$ ]]; then
    echo -e "${RED}Error: Environment must be 'stg' or 'prd'${NC}" >&2
    exit 1
fi

# Extract project ID from service account email
# Format: sa-name@project-id.iam.gserviceaccount.com
if [[ "$SERVICE_ACCOUNT_EMAIL" =~ @([^.]+)\.iam\.gserviceaccount\.com$ ]]; then
    PROJECT_ID="${BASH_REMATCH[1]}"
else
    echo -e "${RED}Error: Invalid service account email format${NC}" >&2
    echo -e "${YELLOW}Expected format: sa-name@project-id.iam.gserviceaccount.com${NC}" >&2
    exit 1
fi

# Set environment file based on environment
if [ "$ENVIRONMENT" == "stg" ]; then
    ENV_FILE="${REPO_ROOT}/.env.stg"
else
    ENV_FILE="${REPO_ROOT}/.env.prd"
fi

# Check if general script exists
if [ ! -f "$GENERAL_SCRIPT" ]; then
    echo -e "${RED}Error: General script not found at $GENERAL_SCRIPT${NC}" >&2
    echo "" >&2
    echo -e "${YELLOW}Hint: Ensure pcioasis-ops repository is checked out at:${NC}" >&2
    echo -e "  ${REPO_ROOT}/../pcioasis-ops/secrets" >&2
    echo "" >&2
    echo -e "${BLUE}Expected file:${NC} create-service-account-key-and-update-env.sh" >&2
    exit 1
fi

# Determine variable name based on service account email
# The general script will infer this, but we need it for checking existence
# For Firebase Admin SDK, use FIREBASE_SERVICE_ACCOUNT_KEY
# For others, infer from service account name
if [[ "$SERVICE_ACCOUNT_EMAIL" == *"firebase"* ]] || [[ "$SERVICE_ACCOUNT_EMAIL" == *"fbase"* ]]; then
    VAR_NAME="FIREBASE_SERVICE_ACCOUNT_KEY"
else
    # Generic: extract service account name and create variable
    SA_NAME=$(echo "$SERVICE_ACCOUNT_EMAIL" | cut -d'@' -f1 | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    VAR_NAME="${SA_NAME}_SERVICE_ACCOUNT_KEY"
fi

# Check if variable already exists in .env file
KEY_EXISTS=false
KEY_ENCRYPTED=false

if [ -f "$ENV_FILE" ]; then
    if grep -q "^${VAR_NAME}=" "$ENV_FILE" 2>/dev/null; then
        KEY_EXISTS=true
        if grep -q "^${VAR_NAME}=encrypted:" "$ENV_FILE" 2>/dev/null; then
            KEY_ENCRYPTED=true
        fi
    fi
fi

if [ "$KEY_EXISTS" = true ]; then
    if [ "$KEY_ENCRYPTED" = true ]; then
        echo -e "${YELLOW}⚠️  ${VAR_NAME} already exists and is encrypted in ${ENV_FILE}${NC}"
    else
        echo -e "${YELLOW}⚠️  ${VAR_NAME} already exists (not encrypted) in ${ENV_FILE}${NC}"
    fi

    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}Do you want to rotate it? (y/N):${NC} "
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Aborted. Existing key will be preserved.${NC}"
            exit 0
        fi
    else
        echo -e "${BLUE}--quiet flag set: Auto-rotating key...${NC}"
    fi

    # Remove existing key from .env file to allow rotation
    echo -e "${YELLOW}Removing existing ${VAR_NAME} from ${ENV_FILE}...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^${VAR_NAME}=/d" "$ENV_FILE"
    else
        sed -i "/^${VAR_NAME}=/d" "$ENV_FILE"
    fi
    echo -e "${GREEN}✓ Removed existing ${VAR_NAME}${NC}"
    echo ""

    echo -e "${GREEN}=== Rotating Service Account Key ===${NC}"
else
    echo -e "${GREEN}=== Creating Service Account Key ===${NC}"
fi

echo -e "${BLUE}Environment:${NC} $ENVIRONMENT"
echo -e "${BLUE}Project:${NC} $PROJECT_ID"
echo -e "${BLUE}Service Account:${NC} $SERVICE_ACCOUNT_EMAIL"
echo ""

# Check if service account exists and provide helpful error message
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
    echo -e "${RED}Error: Service account $SERVICE_ACCOUNT_EMAIL does not exist${NC}" >&2
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Service Account Management: Terraform vs gcloud${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Terraform manages:${NC}"
    echo -e "  • Service account creation"
    echo -e "  • IAM bindings and permissions"
    echo -e "  • Cross-project IAM (Firebase Admin SDK access)"
    echo ""
    echo -e "${BLUE}gcloud manages:${NC}"
    echo -e "  • Service account keys (credentials)"
    echo ""
    echo -e "${YELLOW}Step 1: Create service account with Terraform${NC}"
    echo -e "  cd ${REPO_ROOT}/deploy/terraform-home" >&2
    echo -e "  terraform init -backend-config=backend-${ENVIRONMENT}.conf" >&2
    echo -e "  terraform apply" >&2
    echo ""
    echo -e "${YELLOW}Step 2: Then run this script again to create the key${NC}"
    echo -e "  ${SCRIPT_DIR}/$(basename "$0") ${SERVICE_ACCOUNT_EMAIL} ${ENVIRONMENT} [--quiet]" >&2
    echo ""
    exit 1
fi

# Call the general-purpose script

exec "$GENERAL_SCRIPT" \
    "$SERVICE_ACCOUNT_EMAIL" \
    "$PROJECT_ID" \
    "$ENVIRONMENT" \
    "$GITHUB_SECRET_NAME"
