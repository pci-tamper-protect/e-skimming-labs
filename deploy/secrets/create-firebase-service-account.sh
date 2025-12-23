#!/bin/bash

# Create Firebase Service Account for Labs Authentication
# This script creates a restricted service account for labs that can set custom claims
# but has limited Firestore access (following least privilege principle)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${GREEN}=== $1 ===${NC}"
}

print_status() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
SERVICE_ACCOUNT_NAME="labs-auth-validator"
CUSTOM_ROLE_NAME="labs.firebase.authValidator"

# Parse environment argument (first positional argument)
# Always use argument if provided, ignore ENVIRONMENT env var
if [ -n "$1" ]; then
    ENVIRONMENT="$1"
else
    ENVIRONMENT="${ENVIRONMENT:-prd}"
fi

# Normalize environment and set Firebase project ID
if [ "$ENVIRONMENT" = "stg" ] || [ "$ENVIRONMENT" = "staging" ]; then
    ENVIRONMENT="stg"
    FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-ui-firebase-pcioasis-stg}"
elif [ "$ENVIRONMENT" = "prd" ] || [ "$ENVIRONMENT" = "production" ]; then
    ENVIRONMENT="prd"
    FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-ui-firebase-pcioasis-prd}"
else
    print_error "Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 [stg|prd]"
    echo "Example: $0 stg"
    echo "Example: $0 prd"
    exit 1
fi

SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${FIREBASE_PROJECT_ID}.iam.gserviceaccount.com"

# Check required tools
check_requirements() {
    print_header "Checking Requirements"

    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is required but not installed"
        exit 1
    fi

    print_status "All requirements met ✓"
}

# Verify Firebase project access
verify_project() {
    print_header "Verifying Firebase Project Access"
    
    if ! gcloud projects describe "$FIREBASE_PROJECT_ID" &> /dev/null; then
        print_error "Cannot access project: $FIREBASE_PROJECT_ID"
        print_info "Make sure you have access to this project"
        exit 1
    fi
    
    print_status "Project access verified: $FIREBASE_PROJECT_ID ✓"
}

# Create custom IAM role for labs authentication
create_custom_role() {
    print_header "Creating Custom IAM Role"

    ROLE_FILE=$(mktemp)
    cat > "$ROLE_FILE" <<EOF
{
  "title": "Labs Firebase Auth Validator",
  "description": "Restricted role for labs authentication. Allows setting custom claims but has no Firestore access.",
  "includedPermissions": [
    "firebaseauth.users.update",
    "firebaseauth.users.get"
  ],
  "stage": "GA"
}
EOF

    # Check if role already exists
    if gcloud iam roles describe "$CUSTOM_ROLE_NAME" --project="$FIREBASE_PROJECT_ID" &> /dev/null; then
        print_status "Custom role $CUSTOM_ROLE_NAME already exists"
        print_info "Updating existing role..."
        gcloud iam roles update "$CUSTOM_ROLE_NAME" \
            --project="$FIREBASE_PROJECT_ID" \
            --file="$ROLE_FILE" || {
            print_error "Failed to update role"
            rm -f "$ROLE_FILE"
            exit 1
        }
        print_status "Role updated ✓"
    else
        print_info "Creating new custom role..."
        gcloud iam roles create "$CUSTOM_ROLE_NAME" \
            --project="$FIREBASE_PROJECT_ID" \
            --file="$ROLE_FILE" || {
            print_error "Failed to create role"
            rm -f "$ROLE_FILE"
            exit 1
        }
        print_status "Custom role created ✓"
    fi

    rm -f "$ROLE_FILE"
}

# Create service account
create_service_account() {
    print_header "Creating Service Account"

    if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$FIREBASE_PROJECT_ID" &> /dev/null; then
        print_status "Service account $SERVICE_ACCOUNT_EMAIL already exists ✓"
    else
        gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
            --display-name="Labs Firebase Auth Validator" \
            --description="Restricted service account for labs authentication. Can set custom claims but has no Firestore access." \
            --project="$FIREBASE_PROJECT_ID" || {
            print_error "Failed to create service account"
            exit 1
        }
        print_status "Service account created ✓"
    fi
}

# Grant custom role to service account
grant_role() {
    print_header "Granting Custom Role to Service Account"

    gcloud projects add-iam-policy-binding "$FIREBASE_PROJECT_ID" \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="projects/$FIREBASE_PROJECT_ID/roles/$CUSTOM_ROLE_NAME" || {
        print_error "Failed to grant role to service account"
        exit 1
    }

    print_status "Custom role granted to service account ✓"
}

# Create and download service account key
create_service_account_key() {
    print_header "Creating Service Account Key"

    KEY_FILE="${REPO_ROOT}/deploy/${SERVICE_ACCOUNT_NAME}-${ENVIRONMENT}-key.json"
    
    # Check if key already exists
    if [ -f "$KEY_FILE" ]; then
        print_status "Service account key already exists at $KEY_FILE"
        read -p "Do you want to create a new key? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping key creation"
            return
        fi
    fi

    # Create new key
    gcloud iam service-accounts keys create "$KEY_FILE" \
        --iam-account="$SERVICE_ACCOUNT_EMAIL" \
        --project="$FIREBASE_PROJECT_ID" || {
        print_error "Failed to create service account key"
        exit 1
    }

    print_status "Service account key created: $KEY_FILE ✓"
    
    # Add key to .env file and encrypt
    add_key_to_env_and_encrypt
}

# Print manual steps for encrypting .env file
print_manual_steps() {
    local env_file="$1"
    local key_file="$2"
    local converter_script="$3"
    
    echo ""
    print_header "Manual Steps Required"
    echo ""
    echo "1. Encrypt the .env file using dotenvx-converter.py:"
    echo "   python3 ${converter_script} ${env_file}"
    echo ""
    echo "   Or if dotenvx-converter.py is not available, use dotenvx CLI:"
    echo "   dotenvx encrypt ${env_file}"
    echo ""
    echo "2. After encryption, remove the temporary key file:"
    echo "   rm -f ${key_file}"
    echo ""
    print_info "Service account key location: ${key_file}"
    print_info ".env file location: ${env_file}"
}

# Add service account key to .env file and encrypt
add_key_to_env_and_encrypt() {
    print_header "Adding Service Account Key to .env File"
    
    ENV_FILE="${REPO_ROOT}/.env.${ENVIRONMENT}"
    CONVERTER_SCRIPT="${REPO_ROOT}/../pcioasis-ops/secrets/dotenvx-converter.py"
    
    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        print_status "Creating new .env file: $ENV_FILE"
        touch "$ENV_FILE"
    fi
    
    # Read the JSON key file and escape it for multiline .env value
    # Use double quotes and escape newlines with \n
    # Use Python to properly escape the JSON string
    KEY_JSON=$(python3 -c "
import json
import sys
with open('$KEY_FILE', 'r') as f:
    content = f.read()
# Escape for .env file: replace newlines with \n and escape quotes
escaped = content.replace('\\\\', '\\\\\\\\').replace('\n', '\\\\n').replace('\"', '\\\\\"')
print(escaped, end='')
")
    
    # Check if FIREBASE_SERVICE_ACCOUNT already exists in .env file
    if grep -q "^FIREBASE_SERVICE_ACCOUNT=" "$ENV_FILE"; then
        print_status "FIREBASE_SERVICE_ACCOUNT already exists in $ENV_FILE"
        read -p "Do you want to update it? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping .env update"
            return
        fi
        # Remove existing line (macOS-compatible)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/^FIREBASE_SERVICE_ACCOUNT=/d' "$ENV_FILE"
        else
            sed -i '/^FIREBASE_SERVICE_ACCOUNT=/d' "$ENV_FILE"
        fi
    fi
    
    # Add the key to .env file with proper multiline formatting
    echo "FIREBASE_SERVICE_ACCOUNT=\"${KEY_JSON}\"" >> "$ENV_FILE"
    print_status "Added FIREBASE_SERVICE_ACCOUNT to $ENV_FILE ✓"
    
    # Check if dotenvx-converter.py exists
    if [ -f "$CONVERTER_SCRIPT" ]; then
        # Encrypt the .env file using dotenvx-converter.py
        print_status "Encrypting .env file..."
        if python3 "$CONVERTER_SCRIPT" "$ENV_FILE"; then
            print_status ".env file encrypted successfully ✓"
            # Remove the key file after successful encryption
            print_status "Removing temporary key file..."
            rm -f "$KEY_FILE"
            print_status "Temporary key file removed ✓"
        else
            print_error "Failed to encrypt .env file"
            print_manual_steps "$ENV_FILE" "$KEY_FILE" "$CONVERTER_SCRIPT"
        fi
    else
        print_status "dotenvx-converter.py not found at $CONVERTER_SCRIPT"
        print_info "Skipping automatic encryption. Manual steps required:"
        print_manual_steps "$ENV_FILE" "$KEY_FILE" "$CONVERTER_SCRIPT"
    fi
}

# Verify service account setup
verify_setup() {
    print_header "Verifying Service Account Setup"

    # Check service account exists
    if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$FIREBASE_PROJECT_ID" &> /dev/null; then
        print_error "Service account verification failed"
        exit 1
    fi

    # Check role is granted
    ROLES=$(gcloud projects get-iam-policy "$FIREBASE_PROJECT_ID" \
        --flatten="bindings[].members" \
        --filter="bindings.members:serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --format="value(bindings.role)" 2>/dev/null || echo "")

    if echo "$ROLES" | grep -q "$CUSTOM_ROLE_NAME"; then
        print_status "Service account has correct role ✓"
    else
        print_error "Service account does not have expected role"
        print_info "Granted roles: $ROLES"
        exit 1
    fi

    print_status "Setup verification complete ✓"
}

# Main execution
main() {
    print_header "Firebase Service Account Setup for Labs"
    print_info "Environment: $ENVIRONMENT"
    print_info "Firebase Project: $FIREBASE_PROJECT_ID"
    print_info "Service Account: $SERVICE_ACCOUNT_EMAIL"
    echo ""

    check_requirements
    verify_project
    create_custom_role
    create_service_account
    grant_role
    create_service_account_key
    verify_setup

    echo ""
    print_header "Setup Complete"
    print_info "Next steps:"
    echo "  1. Service account key has been added to ${REPO_ROOT}/.env.${ENVIRONMENT} and encrypted ✓"
    echo "  2. Update Firestore security rules to check custom claims"
    echo "  3. Deploy Cloud Function or backend service to set custom claims on sign-up"
}

# Run main function
main "$@"

