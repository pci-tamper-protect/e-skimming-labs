#!/bin/bash
# Import existing GCP resources into Terraform state
# This script helps import resources that already exist in GCP

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment configuration from repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    if [ -L "$REPO_ROOT/.env" ]; then
        TARGET=$(readlink "$REPO_ROOT/.env")
        echo "📋 Using .env -> $TARGET"
    else
        echo "📋 Using .env"
    fi
    source "$REPO_ROOT/.env"
elif [ -f "$REPO_ROOT/.env.prd" ]; then
    echo "📋 Using .env.prd from repo root (create symlink: ln -s .env.prd .env)"
    source "$REPO_ROOT/.env.prd"
elif [ -f "$REPO_ROOT/.env.stg" ]; then
    echo "📋 Using .env.stg from repo root (create symlink: ln -s .env.stg .env)"
    source "$REPO_ROOT/.env.stg"
else
    echo "❌ .env file not found in repo root: $REPO_ROOT"
    echo ""
    echo "Please create a .env file in repo root:"
    echo "  ln -s .env.stg .env  # for staging"
    echo "  ln -s .env.prd .env  # for production"
    exit 1
fi

PROJECT_ID="${LABS_PROJECT_ID:-labs-stg}"
REGION="${LABS_REGION:-us-central1}"

# Determine environment
if [[ "$PROJECT_ID" == *"-stg" ]]; then
    ENVIRONMENT="stg"
    BACKEND_CONFIG="backend-stg.conf"
elif [[ "$PROJECT_ID" == *"-prd" ]]; then
    ENVIRONMENT="prd"
    BACKEND_CONFIG="backend-prd.conf"
else
    echo "❌ Cannot determine environment from project ID: $PROJECT_ID"
    exit 1
fi

echo "📥 Importing Existing Resources"
echo "================================"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo ""

cd "$SCRIPT_DIR"

# Initialize with correct backend
echo "🔧 Initializing Terraform with $ENVIRONMENT backend..."
terraform init -backend-config="$BACKEND_CONFIG" >/dev/null 2>&1 || {
    echo "❌ Failed to initialize Terraform"
    exit 1
}

echo ""

# Import Artifact Registry repository
echo "📦 Importing Artifact Registry repository..."
if terraform state show google_artifact_registry_repository.labs_repo >/dev/null 2>&1; then
    echo "   ✅ Already in state"
else
    REPO_ID="projects/$PROJECT_ID/locations/$REGION/repositories/e-skimming-labs"
    if terraform import google_artifact_registry_repository.labs_repo "$REPO_ID" 2>&1; then
        echo "   ✅ Imported: $REPO_ID"
    else
        echo "   ⚠️  Failed to import (may not exist or wrong ID)"
    fi
fi

echo ""

# Import Firestore database
echo "🔥 Importing Firestore database..."
if terraform state show google_firestore_database.labs_db >/dev/null 2>&1; then
    echo "   ✅ Already in state"
else
    # Firestore database import format: projects/{project}/databases/{database}
    DB_ID="projects/$PROJECT_ID/databases/(default)"
    if terraform import google_firestore_database.labs_db "$DB_ID" 2>&1; then
        echo "   ✅ Imported: $DB_ID"
    else
        echo "   ⚠️  Failed to import (may not exist or wrong ID)"
        echo "   Note: Firestore database ID format: projects/{project}/databases/{database}"
    fi
fi

echo ""

# Import Storage buckets
echo "📦 Importing Storage buckets..."
if terraform state show google_storage_bucket.labs_data >/dev/null 2>&1; then
    echo "   ✅ labs_data already in state"
else
    BUCKET_NAME="${PROJECT_ID}-labs-data"
    if terraform import google_storage_bucket.labs_data "$BUCKET_NAME" 2>&1; then
        echo "   ✅ Imported: $BUCKET_NAME"
    else
        echo "   ⚠️  Failed to import labs_data bucket"
    fi
fi

if terraform state show google_storage_bucket.labs_logs >/dev/null 2>&1; then
    echo "   ✅ labs_logs already in state"
else
    BUCKET_NAME="${PROJECT_ID}-labs-logs"
    if terraform import google_storage_bucket.labs_logs "$BUCKET_NAME" 2>&1; then
        echo "   ✅ Imported: $BUCKET_NAME"
    else
        echo "   ⚠️  Failed to import labs_logs bucket"
    fi
fi

echo ""

# Cloud Run Services - NOT imported (managed by GitHub Actions, not Terraform)
# See TERRAFORM_SCOPE.md for architectural details
echo ""
echo "⚠️  Cloud Run services are NOT managed by Terraform"
echo "   They are deployed and managed by GitHub Actions workflows"
echo "   IAM bindings use data sources to reference services"
echo "   If services are in state, remove them: ./remove-cloud-run-from-state.sh ${ENVIRONMENT}"

echo ""
echo "================================================"
echo "✅ Import complete"
echo ""
echo "Next steps:"
echo "  1. Run: terraform plan -var='environment=$ENVIRONMENT' -var='deploy_services=true'"
echo "  2. Review the plan to ensure no unexpected changes"
echo "  3. Apply if everything looks correct"
echo ""
echo "Note: Cloud Run services are NOT imported (managed by GitHub Actions)"
echo "  If they're in state, remove them: ./remove-cloud-run-from-state.sh ${ENVIRONMENT}"
