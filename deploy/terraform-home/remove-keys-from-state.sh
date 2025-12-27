#!/bin/bash
# Remove service account keys from Terraform state without destroying them
#
# This script safely removes key resources from Terraform state.
# The actual keys in GCP remain intact - only Terraform's tracking is removed.
#
# Usage:
#   ./remove-keys-from-state.sh [environment]
#
# Examples:
#   ./remove-keys-from-state.sh stg
#   ./remove-keys-from-state.sh prd

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT="${1:-}"

if [ -z "$ENVIRONMENT" ]; then
    echo -e "${RED}Usage: $0 <environment>${NC}" >&2
    echo "Example: $0 stg" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${GREEN}=== Removing Service Account Keys from Terraform State ===${NC}"
echo -e "${BLUE}Environment:${NC} $ENVIRONMENT"
echo ""
echo -e "${YELLOW}This will remove keys from Terraform state but NOT destroy them in GCP${NC}"
echo ""

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo -e "${RED}Error: Terraform not initialized${NC}" >&2
    echo "Run: terraform init -backend-config=backend-${ENVIRONMENT}.conf" >&2
    exit 1
fi

# List of keys to remove
KEYS_TO_REMOVE=(
    "google_service_account_key.home_deploy_key"
    "google_service_account_key.fbase_adm_sdk_runtime_key"
)

REMOVED_COUNT=0
NOT_FOUND_COUNT=0

for key_resource in "${KEYS_TO_REMOVE[@]}"; do
    echo -e "${YELLOW}Checking: $key_resource${NC}"

    # Check if resource exists in state
    if terraform state list 2>/dev/null | grep -q "^${key_resource}$"; then
        echo -e "${BLUE}  Found in state, removing...${NC}"
        if terraform state rm "$key_resource" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Removed from state${NC}"
            ((REMOVED_COUNT++))
        else
            echo -e "${RED}  ✗ Failed to remove${NC}" >&2
        fi
    else
        echo -e "${BLUE}  Not in state (already removed or never created)${NC}"
        ((NOT_FOUND_COUNT++))
    fi
    echo ""
done

echo -e "${GREEN}=== Summary ===${NC}"
echo "  Removed from state: $REMOVED_COUNT"
echo "  Not found in state: $NOT_FOUND_COUNT"
echo ""

if [ $REMOVED_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓ Keys removed from Terraform state${NC}"
    echo -e "${BLUE}Note: The actual keys in GCP are still intact and functional${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Verify keys still exist in GCP (they should!)"
    echo "  2. Run 'terraform plan' to verify no destroy operations"
    echo "  3. The resource definitions can now be safely removed from code"
else
    echo -e "${BLUE}No keys were in Terraform state to remove${NC}"
    echo "This is fine - the resource definitions can be safely removed from code"
fi
