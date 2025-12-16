#!/bin/bash
# Verify that all Cloud Run services have proper access control
# Staging services should only allow 2025-interns and core-eng groups
# Production services should allow allUsers (public)

set -e

# Get the directory where this script is located
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
elif [ -f "$SCRIPT_DIR/.env.prd" ]; then
    echo "📋 Using .env.prd"
    source "$SCRIPT_DIR/.env.prd"
elif [ -f "$SCRIPT_DIR/.env.stg" ]; then
    echo "📋 Using .env.stg"
    source "$SCRIPT_DIR/.env.stg"
else
    echo "❌ .env file not found in $SCRIPT_DIR"
    exit 1
fi

LABS_PROJECT_ID="${LABS_PROJECT_ID:-}"
HOME_PROJECT_ID="${HOME_PROJECT_ID:-}"
REGION="${LABS_REGION:-${HOME_REGION:-us-central1}}"

# Determine environment from project ID
if [[ "$LABS_PROJECT_ID" == *"-stg" ]] || [[ "$HOME_PROJECT_ID" == *"-stg" ]]; then
    ENVIRONMENT="stg"
elif [[ "$LABS_PROJECT_ID" == *"-prd" ]] || [[ "$HOME_PROJECT_ID" == *"-prd" ]]; then
    ENVIRONMENT="prd"
else
    echo "❌ Cannot determine environment from project IDs"
    exit 1
fi

echo "🔒 Verifying Cloud Run Access Control"
echo "======================================"
echo "Environment: $ENVIRONMENT"
echo "Labs Project: ${LABS_PROJECT_ID:-not set}"
echo "Home Project: ${HOME_PROJECT_ID:-not set}"
echo "Region: $REGION"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed"
    exit 1
fi

# Function to check service IAM policy
check_service_access() {
    local project="$1"
    local service="$2"
    local region="$3"
    
    echo "  Checking: $service"
    
    # Get IAM policy
    local policy=$(gcloud run services get-iam-policy "$service" \
        --region="$region" \
        --project="$project" \
        --format=json 2>/dev/null || echo "{}")
    
    if [ "$policy" = "{}" ]; then
        echo "    ⚠️  Could not retrieve IAM policy (service may not exist)"
        return 1
    fi
    
    # Check for allUsers (public access)
    if echo "$policy" | jq -e '.bindings[] | select(.members[] == "allUsers")' &>/dev/null; then
        if [ "$ENVIRONMENT" = "stg" ]; then
            echo "    ❌ PUBLIC ACCESS DETECTED (should be restricted in staging!)"
            return 1
        else
            echo "    ✅ Public access (expected for production)"
        fi
    else
        if [ "$ENVIRONMENT" = "stg" ]; then
            echo "    ✅ No public access (correct for staging)"
        else
            echo "    ⚠️  No public access (unexpected for production)"
        fi
    fi
    
    # Check for group access
    local has_interns=$(echo "$policy" | jq -e '.bindings[] | select(.members[] == "group:2025-interns@pcioasis.com")' &>/dev/null && echo "yes" || echo "no")
    local has_core_eng=$(echo "$policy" | jq -e '.bindings[] | select(.members[] == "group:core-eng@pcioasis.com")' &>/dev/null && echo "yes" || echo "no")
    
    if [ "$ENVIRONMENT" = "stg" ]; then
        if [ "$has_interns" = "yes" ] && [ "$has_core_eng" = "yes" ]; then
            echo "    ✅ Group access configured (2025-interns, core-eng)"
        else
            echo "    ⚠️  Missing group access:"
            [ "$has_interns" = "no" ] && echo "      - Missing: 2025-interns@pcioasis.com"
            [ "$has_core_eng" = "no" ] && echo "      - Missing: core-eng@pcioasis.com"
        fi
    fi
    
    return 0
}

# Check Labs Project services
if [ -n "$LABS_PROJECT_ID" ]; then
    echo "📦 Labs Project Services ($LABS_PROJECT_ID):"
    gcloud config set project "$LABS_PROJECT_ID" --quiet
    
    # Analytics service
    check_service_access "$LABS_PROJECT_ID" "labs-analytics-$ENVIRONMENT" "$REGION"
    
    # Index service
    check_service_access "$LABS_PROJECT_ID" "labs-index-$ENVIRONMENT" "$REGION"
    
    # Individual lab services
    echo ""
    echo "  Individual Lab Services:"
    for lab in lab-01-basic-magecart lab-02-dom-skimming lab-03-extension-hijacking; do
        check_service_access "$LABS_PROJECT_ID" "$lab-$ENVIRONMENT" "$REGION" || true
    done
fi

# Check Home Project services
if [ -n "$HOME_PROJECT_ID" ]; then
    echo ""
    echo "📦 Home Project Services ($HOME_PROJECT_ID):"
    gcloud config set project "$HOME_PROJECT_ID" --quiet
    
    # SEO service
    check_service_access "$HOME_PROJECT_ID" "home-seo-$ENVIRONMENT" "$REGION"
    
    # Index service
    check_service_access "$HOME_PROJECT_ID" "home-index-$ENVIRONMENT" "$REGION"
fi

echo ""
echo "✅ Access control verification complete"
echo ""
echo "Summary:"
if [ "$ENVIRONMENT" = "stg" ]; then
    echo "  - Staging services should have NO public access (allUsers)"
    echo "  - Staging services should allow: 2025-interns@pcioasis.com, core-eng@pcioasis.com"
else
    echo "  - Production services should have public access (allUsers)"
fi

