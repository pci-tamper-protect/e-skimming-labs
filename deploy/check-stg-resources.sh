#!/bin/bash
# Check STG GCP projects for resources misnamed with -prd tags
# This script verifies that all resources in STG projects use -stg naming

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

# Verify we're checking STG projects
if [[ "$LABS_PROJECT_STG" != *"-stg" ]] && [[ "$HOME_PROJECT_STG" != *"-stg" ]]; then
    echo "⚠️  Warning: Projects don't appear to be STG:"
    echo "   LABS_PROJECT_ID: $LABS_PROJECT_STG"
    echo "   HOME_PROJECT_ID: $HOME_PROJECT_STG"
    echo "   Set .env to point to .env.stg"
    exit 1
fi

echo "🔍 Checking STG Projects for Misnamed Resources"
echo "================================================"
echo "Labs Project: $LABS_PROJECT_STG"
echo "Home Project: $HOME_PROJECT_STG"
echo ""

ERRORS=0

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Cannot check GCP resources."
    exit 1
fi

# Function to check for PRD naming in resource list
check_for_prd_naming() {
    local project="$1"
    local resource_type="$2"
    local command="$3"
    
    echo "  Checking $resource_type in $project..."
    
    # Run the command and check for -prd in output
    if OUTPUT=$($command 2>/dev/null); then
        PRD_RESOURCES=$(echo "$OUTPUT" | grep -i "\-prd" || true)
        if [ -n "$PRD_RESOURCES" ]; then
            echo "    ❌ Found resources with -prd naming:"
            echo "$PRD_RESOURCES" | sed 's/^/      /'
            return 1
        else
            echo "    ✅ No -prd naming found"
            return 0
        fi
    else
        echo "    ⚠️  Could not check (may not have permissions or resources don't exist)"
        return 0
    fi
}

# Check Labs Project
if [ -n "$LABS_PROJECT_STG" ] && [[ "$LABS_PROJECT_STG" == *"-stg" ]]; then
    echo "📁 Checking Labs Project: $LABS_PROJECT_STG"
    echo ""
    
    # Cloud Run services
    if ! check_for_prd_naming "$LABS_PROJECT_STG" "Cloud Run Services" \
        "gcloud run services list --project=$LABS_PROJECT_STG --format='table(SERVICE,REGION)'"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    # Service Accounts
    if ! check_for_prd_naming "$LABS_PROJECT_STG" "Service Accounts" \
        "gcloud iam service-accounts list --project=$LABS_PROJECT_STG --format='table(EMAIL)'"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    # Artifact Registry repositories
    if ! check_for_prd_naming "$LABS_PROJECT_STG" "Artifact Registry" \
        "gcloud artifacts repositories list --project=$LABS_PROJECT_STG --location=us-central1 --format='table(NAME)'"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    # Cloud Storage buckets
    if ! check_for_prd_naming "$LABS_PROJECT_STG" "Storage Buckets" \
        "gsutil ls -p $LABS_PROJECT_STG 2>/dev/null | grep -v '^$' || echo ''"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    # Firestore databases (check name)
    if ! check_for_prd_naming "$LABS_PROJECT_STG" "Firestore Databases" \
        "gcloud firestore databases list --project=$LABS_PROJECT_STG --format='table(NAME)' 2>/dev/null || echo ''"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    echo ""
fi

# Check Home Project
if [ -n "$HOME_PROJECT_STG" ] && [[ "$HOME_PROJECT_STG" == *"-stg" ]]; then
    echo "📁 Checking Home Project: $HOME_PROJECT_STG"
    echo ""
    
    # Cloud Run services
    if ! check_for_prd_naming "$HOME_PROJECT_STG" "Cloud Run Services" \
        "gcloud run services list --project=$HOME_PROJECT_STG --format='table(SERVICE,REGION)'"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    # Service Accounts
    if ! check_for_prd_naming "$HOME_PROJECT_STG" "Service Accounts" \
        "gcloud iam service-accounts list --project=$HOME_PROJECT_STG --format='table(EMAIL)'"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    # Artifact Registry repositories
    if ! check_for_prd_naming "$HOME_PROJECT_STG" "Artifact Registry" \
        "gcloud artifacts repositories list --project=$HOME_PROJECT_STG --location=us-central1 --format='table(NAME)'"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    # Cloud Storage buckets
    if ! check_for_prd_naming "$HOME_PROJECT_STG" "Storage Buckets" \
        "gsutil ls -p $HOME_PROJECT_STG 2>/dev/null | grep -v '^$' || echo ''"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    # Firestore databases
    if ! check_for_prd_naming "$HOME_PROJECT_STG" "Firestore Databases" \
        "gcloud firestore databases list --project=$HOME_PROJECT_STG --format='table(NAME)' 2>/dev/null || echo ''"; then
        ERRORS=$((ERRORS + 1))
    fi
    
    echo ""
fi

# Summary
echo "================================================"
if [ $ERRORS -eq 0 ]; then
    echo "✅ All STG resources use correct -stg naming"
    exit 0
else
    echo "❌ Found $ERRORS issue(s) with -prd naming in STG projects"
    echo ""
    echo "To fix:"
    echo "  1. Review the resources listed above"
    echo "  2. Rename or delete misnamed resources"
    echo "  3. Re-run this script to verify"
    exit 1
fi

