#!/bin/bash

# Script to upload dotenvx private key to Google Cloud Secret Manager
# Usage: ./deploy/upload-dotenvx-key.sh [stg|prd] [PROJECT_ID]
# 
# IMPORTANT: For home services, you need to upload the secret to BOTH projects:
#   1. ./deploy/upload-dotenvx-key.sh stg labs-stg      (for labs services)
#   2. ./deploy/upload-dotenvx-key.sh stg labs-home-stg (for home services)

set -e

ENV="${1:-stg}"
PROJECT_ID="${2}"

if [ -z "$PROJECT_ID" ]; then
    echo "Error: PROJECT_ID is required"
    echo "Usage: $0 [stg|prd] PROJECT_ID"
    echo "Example: $0 stg labs-stg"
    echo "Example: $0 prd labs-prd"
    exit 1
fi

# Normalize environment name
if [ "$ENV" = "stg" ] || [ "$ENV" = "staging" ]; then
    ENV="stg"
    SECRET_NAME="DOTENVX_KEY_STG"
elif [ "$ENV" = "prd" ] || [ "$ENV" = "production" ]; then
    ENV="prd"
    SECRET_NAME="DOTENVX_KEY_PRD"
else
    echo "Error: Environment must be 'stg' or 'prd'"
    exit 1
fi

KEY_FILE=".env.keys.${ENV}"

if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Key file '$KEY_FILE' not found"
    echo "Please ensure the dotenvx private key file exists in the repository root"
    exit 1
fi

echo "Uploading dotenvx private key for ${ENV} environment..."
echo "Project: ${PROJECT_ID}"
echo "Secret name: ${SECRET_NAME}"
echo "Key file: ${KEY_FILE}"
echo ""

# Verify gcloud is available and authenticated
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed or not in PATH"
    exit 1
fi

# Check if user is authenticated (more lenient check)
ACTIVE_ACCOUNTS=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || echo "")
if [ -z "$ACTIVE_ACCOUNTS" ]; then
    # Try alternative check
    ACTIVE_ACCOUNTS=$(gcloud config get-value account 2>/dev/null || echo "")
    if [ -z "$ACTIVE_ACCOUNTS" ] || [ "$ACTIVE_ACCOUNTS" = "(unset)" ]; then
        echo "⚠️  Warning: No active gcloud authentication found"
        echo "Run: gcloud auth login"
        echo "Or: gcloud auth application-default login"
        exit 1
    fi
fi
echo "✅ Authenticated as: $(gcloud config get-value account 2>/dev/null || echo 'unknown')"

# Verify project access (with verbose output to diagnose hangs)
echo "Verifying access to project ${PROJECT_ID}..."
if ! gcloud projects describe "${PROJECT_ID}" 2>&1; then
    echo "❌ Error: Cannot access project ${PROJECT_ID}"
    echo "Make sure you have access to this project and it exists"
    exit 1
fi
echo "✅ Project access verified"

echo "Attempting to create or update secret..."
# Try to create the secret first. If it already exists, add a new version instead.
# This avoids the need to check if it exists (which can hang)
# Temporarily disable set -e for this section
set +e
echo "Trying to create secret (this may take a moment)..."
gcloud secrets create "${SECRET_NAME}" \
    --project="${PROJECT_ID}" \
    --data-file="${KEY_FILE}" \
    --replication-policy="automatic" 2>&1
CREATE_EXIT=$?
set -e

if [ $CREATE_EXIT -eq 0 ]; then
    echo "✅ Successfully created new secret ${SECRET_NAME}"
else
    # Check if error is because secret already exists
    echo "Create failed. Checking if secret already exists..."
    set +e
    gcloud secrets describe "${SECRET_NAME}" --project="${PROJECT_ID}" 2>&1
    DESCRIBE_EXIT=$?
    set -e
    
    if [ $DESCRIBE_EXIT -eq 0 ]; then
        echo "Secret ${SECRET_NAME} already exists. Adding new version..."
        gcloud secrets versions add "${SECRET_NAME}" \
            --project="${PROJECT_ID}" \
            --data-file="${KEY_FILE}" || {
            echo "❌ Error: Failed to add new version to secret"
            echo "Make sure you have the 'roles/secretmanager.secretAdmin' role on project ${PROJECT_ID}"
            exit 1
        }
        echo "✅ Successfully added new version to existing secret"
    else
        echo "❌ Error: Failed to create secret"
        echo "The secret doesn't exist and creation failed."
        echo "Make sure you have the 'roles/secretmanager.admin' role on project ${PROJECT_ID}"
        exit 1
    fi
fi

echo ""
echo "Granting Cloud Run service accounts access to the secret..."

# Determine which service accounts need access based on environment
# Note: Secrets need to exist in BOTH projects (labs and home) OR we need cross-project access
if [[ "$ENV" == "stg" ]]; then
    LABS_PROJECT="labs-stg"
    HOME_PROJECT="labs-home-stg"
elif [[ "$ENV" == "prd" ]]; then
    LABS_PROJECT="labs-prd"
    HOME_PROJECT="labs-home-prd"
else
    # Fallback: assume project ID matches the pattern
    LABS_PROJECT="$PROJECT_ID"
    HOME_PROJECT=""
fi

# Grant access to labs runtime service account (in labs project)
LABS_SA="labs-runtime-sa@${LABS_PROJECT}.iam.gserviceaccount.com"
echo "Granting access to ${LABS_SA}..."
set +e
gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
    --project="${PROJECT_ID}" \
    --member="serviceAccount:${LABS_SA}" \
    --role="roles/secretmanager.secretAccessor" 2>&1 | grep -v "Updated IAM policy" || true
LABS_EXIT=$?
set -e

if [ $LABS_EXIT -eq 0 ]; then
    echo "✅ Granted access to ${LABS_SA}"
else
    echo "⚠️  Warning: Failed to grant access to ${LABS_SA}"
    echo "   (May already have access, or service account doesn't exist yet)"
fi

# Grant access to home runtime service account (in home project)
# IMPORTANT: The secret must exist in the home project OR we grant cross-project access
if [ -n "$HOME_PROJECT" ]; then
    HOME_SA="home-runtime-sa@${HOME_PROJECT}.iam.gserviceaccount.com"
    echo "Granting access to ${HOME_SA}..."
    
    # First, check if secret exists in home project
    set +e
    gcloud secrets describe "${SECRET_NAME}" --project="${HOME_PROJECT}" &>/dev/null
    SECRET_EXISTS_IN_HOME=$?
    set -e
    
    if [ $SECRET_EXISTS_IN_HOME -eq 0 ]; then
        # Secret exists in home project, grant access there
        echo "   Secret exists in ${HOME_PROJECT}, granting access..."
        set +e
        gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
            --project="${HOME_PROJECT}" \
            --member="serviceAccount:${HOME_SA}" \
            --role="roles/secretmanager.secretAccessor" 2>&1 | grep -v "Updated IAM policy" || true
        HOME_EXIT=$?
        set -e
    else
        # Secret doesn't exist in home project, grant cross-project access
        echo "   Secret not found in ${HOME_PROJECT}, granting cross-project access from ${PROJECT_ID}..."
        set +e
        gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
            --project="${PROJECT_ID}" \
            --member="serviceAccount:${HOME_SA}" \
            --role="roles/secretmanager.secretAccessor" 2>&1 | grep -v "Updated IAM policy" || true
        HOME_EXIT=$?
        set -e
    fi
    
    if [ $HOME_EXIT -eq 0 ]; then
        echo "✅ Granted access to ${HOME_SA}"
    else
        echo "⚠️  Warning: Failed to grant access to ${HOME_SA}"
        echo ""
        echo "📋 IMPORTANT: The secret must exist in ${HOME_PROJECT} for home services to work."
        echo "   Run this command to upload the secret to the home project:"
        echo "   $0 ${ENV} ${HOME_PROJECT}"
        echo ""
        echo "   Or manually grant access if secret exists:"
        echo "   gcloud secrets add-iam-policy-binding ${SECRET_NAME} \\"
        echo "     --project=${HOME_PROJECT} \\"
        echo "     --member='serviceAccount:${HOME_SA}' \\"
        echo "     --role='roles/secretmanager.secretAccessor'"
    fi
fi

# If we're uploading to labs project, remind user to also upload to home project
if [[ "$PROJECT_ID" == "${LABS_PROJECT}" ]] && [ -n "$HOME_PROJECT" ]; then
    echo ""
    echo "📋 Next step: Upload the secret to ${HOME_PROJECT} for home services:"
    echo "   $0 ${ENV} ${HOME_PROJECT}"
fi

echo ""
echo "✅ Secret upload and access configuration complete!"
echo ""
echo "The GitHub Actions workflow (.github/workflows/deploy_labs.yml) is already"
echo "configured to mount this secret in Cloud Run at /etc/secrets/dotenvx-key"

