#!/bin/bash
# Fix PRD project IDs in STG Terraform state
# This script identifies and helps fix resources with PRD project IDs in STG state

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment configuration
if [ -f "$SCRIPT_DIR/.env" ]; then
    if [ -L "$SCRIPT_DIR/.env" ]; then
        TARGET=$(readlink "$SCRIPT_DIR/.env")
        echo "📋 Using .env -> $TARGET"
    else
        echo "📋 Using .env"
    fi
    source "$SCRIPT_DIR/.env"
elif [ -f "$SCRIPT_DIR/.env.stg" ]; then
    echo "📋 Using .env.stg"
    source "$SCRIPT_DIR/.env.stg"
else
    echo "❌ .env file not found. Please create symlink: ln -s .env.stg .env"
    exit 1
fi

# Determine STG project IDs
LABS_PROJECT_STG="${LABS_PROJECT_ID:-labs-stg}"
HOME_PROJECT_STG="${HOME_PROJECT_ID:-labs-home-stg}"

# Verify we're working with STG
if [[ "$LABS_PROJECT_STG" != *"-stg" ]] && [[ "$HOME_PROJECT_STG" != *"-stg" ]]; then
    echo "⚠️  Warning: Projects don't appear to be STG:"
    echo "   LABS_PROJECT_ID: $LABS_PROJECT_STG"
    echo "   HOME_PROJECT_ID: $HOME_PROJECT_STG"
    echo "   Set .env to point to .env.stg"
    exit 1
fi

echo "🔧 Fixing PRD Project IDs in STG State"
echo "======================================"
echo "Labs Project: $LABS_PROJECT_STG"
echo "Home Project: $HOME_PROJECT_STG"
echo ""

# Function to check and fix resources in a terraform directory
fix_terraform_dir() {
    local TERRAFORM_DIR="$1"
    local PROJECT_STG="$2"
    
    if [ ! -d "$SCRIPT_DIR/$TERRAFORM_DIR" ]; then
        return
    fi
    
    echo "📁 Checking $TERRAFORM_DIR..."
    cd "$SCRIPT_DIR/$TERRAFORM_DIR"
    
    # Initialize with STG backend
    if [ ! -d ".terraform" ]; then
        echo "   Initializing with STG backend..."
        terraform init -backend-config=backend-stg.conf >/dev/null 2>&1 || {
            echo "   ⚠️  Could not initialize. Skipping..."
            return
        }
    fi
    
    # Get resources with PRD project IDs
    echo "   Analyzing state for PRD project IDs..."
    PRD_RESOURCES=$(terraform state pull 2>/dev/null | jq -r --arg stg_proj "$PROJECT_STG" --arg prd_proj "labs-prd" '
        .resources[] | 
        select(.instances[0].attributes.project_id? == $prd_proj or .instances[0].attributes.project? == $prd_proj) |
        "\(.type).\(.name)"
    ' || true)
    
    if [ -z "$PRD_RESOURCES" ]; then
        echo "   ✅ No resources with PRD project IDs found"
        return
    fi
    
    echo "   ❌ Found resources with PRD project IDs:"
    echo "$PRD_RESOURCES" | sed 's/^/      /'
    echo ""
    echo "   These resources need to be updated. Options:"
    echo "   1. Remove from state and re-import with correct project ID"
    echo "   2. Use terraform state mv to update (if resource supports it)"
    echo "   3. Manually update state JSON (not recommended)"
    echo ""
    echo "   To fix, run terraform plan and see what changes are needed."
    echo "   Then either:"
    echo "   - terraform state rm <resource> && terraform import <resource> <id-with-stg-project>"
    echo "   - Or update the resource in GCP and refresh state"
    echo ""
}

# Check each terraform directory
fix_terraform_dir "terraform-labs" "$LABS_PROJECT_STG"
fix_terraform_dir "terraform-home" "$HOME_PROJECT_STG"
fix_terraform_dir "terraform" "$LABS_PROJECT_STG"

echo "================================================"
echo "⚠️  Manual intervention required"
echo ""
echo "The resources listed above have PRD project IDs in STG state."
echo "Review each resource and decide the best fix:"
echo "  1. If the resource should be in STG: Update it in GCP or re-import"
echo "  2. If the resource should be in PRD: Remove it from STG state"
echo ""

