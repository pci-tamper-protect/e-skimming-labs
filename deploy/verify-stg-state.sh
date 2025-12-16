#!/bin/bash
# Verify STG state doesn't contain PRD resources
# This script checks Terraform state for any PRD project references

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

# Determine environment from project ID
if [[ "$LABS_PROJECT_ID" == *"-stg" ]]; then
    ENVIRONMENT="stg"
elif [[ "$LABS_PROJECT_ID" == *"-prd" ]]; then
    ENVIRONMENT="prd"
else
    ENVIRONMENT="${ENVIRONMENT:-stg}"
fi

if [ "$ENVIRONMENT" != "stg" ]; then
    echo "⚠️  Warning: This script is for verifying STG state, but environment is: $ENVIRONMENT"
    echo "   Set .env to point to .env.stg"
    exit 1
fi

echo "🔍 Verifying STG State for PRD Resources"
echo "========================================"
echo "Environment: $ENVIRONMENT"
echo "Labs Project: ${LABS_PROJECT_ID:-not set}"
echo ""

ERRORS=0

# Check each terraform directory
for TERRAFORM_DIR in terraform terraform-labs terraform-home; do
    if [ ! -d "$SCRIPT_DIR/$TERRAFORM_DIR" ]; then
        continue
    fi
    
    echo "📁 Checking $TERRAFORM_DIR..."
    cd "$SCRIPT_DIR/$TERRAFORM_DIR"
    
    # Initialize with STG backend if not already initialized
    if [ ! -d ".terraform" ]; then
        echo "   Initializing with STG backend..."
        terraform init -backend-config=backend-stg.conf >/dev/null 2>&1 || {
            echo "   ⚠️  Could not initialize. Skipping..."
            continue
        }
    fi
    
    # Check state for PRD references
    if terraform state list >/dev/null 2>&1; then
        PRD_RESOURCES=$(terraform state list 2>/dev/null | grep -i "labs-prd\|labs-home-prd" || true)
        
        if [ -n "$PRD_RESOURCES" ]; then
            echo "   ❌ Found PRD resources in STG state:"
            echo "$PRD_RESOURCES" | sed 's/^/      /'
            ERRORS=$((ERRORS + 1))
        else
            echo "   ✅ No PRD resources found"
        fi
        
        # Check for PRD project IDs in state
        STATE_OUTPUT=$(terraform state pull 2>/dev/null | grep -i "labs-prd\|labs-home-prd" || true)
        if [ -n "$STATE_OUTPUT" ]; then
            echo "   ❌ Found PRD project IDs in state JSON"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo "   ℹ️  No state found (empty or not initialized)"
    fi
    
    echo ""
done

if [ $ERRORS -eq 0 ]; then
    echo "✅ STG state is clean - no PRD resources found"
    exit 0
else
    echo "❌ Found $ERRORS issue(s) with PRD resources in STG state"
    echo ""
    echo "To fix:"
    echo "  1. Review the resources listed above"
    echo "  2. Remove PRD resources: terraform state rm <resource_name>"
    echo "  3. Or re-import with correct STG project IDs"
    exit 1
fi

