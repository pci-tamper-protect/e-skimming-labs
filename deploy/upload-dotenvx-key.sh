#!/bin/bash

# Script to upload dotenvx private key to Google Cloud Secret Manager
# Usage: ./deploy/upload-dotenvx-key.sh [stg|prd] [PROJECT_ID]

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

# Check if secret exists
if gcloud secrets describe "${SECRET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Secret ${SECRET_NAME} already exists. Adding new version..."
    gcloud secrets versions add "${SECRET_NAME}" \
        --project="${PROJECT_ID}" \
        --data-file="${KEY_FILE}"
    echo "✅ Successfully added new version to existing secret"
else
    echo "Creating new secret ${SECRET_NAME}..."
    gcloud secrets create "${SECRET_NAME}" \
        --project="${PROJECT_ID}" \
        --data-file="${KEY_FILE}" \
        --replication-policy="automatic"
    echo "✅ Successfully created secret"
fi

echo ""
echo "Next steps:"
echo "1. Grant the Cloud Run service account access to this secret:"
echo "   gcloud secrets add-iam-policy-binding ${SECRET_NAME} \\"
echo "     --project=${PROJECT_ID} \\"
echo "     --member='serviceAccount:<SERVICE_ACCOUNT_EMAIL>' \\"
echo "     --role='roles/secretmanager.secretAccessor'"
echo ""
echo "2. Update .github/workflows/deploy_labs.yml to mount this secret in Cloud Run"
echo "   See deploy/README.md for details"

