#!/bin/bash

# Set Firebase Custom Claims for Labs Users
# This script sets custom claims on Firebase users to track sign-up domain
# Usage: ./deploy/set-firebase-custom-claims.sh <user-id> [environment]

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
USER_ID="$1"
ENVIRONMENT="${2:-prd}"

# Normalize environment
if [ "$ENVIRONMENT" = "stg" ] || [ "$ENVIRONMENT" = "staging" ]; then
    ENVIRONMENT="stg"
    FIREBASE_PROJECT_ID="ui-firebase-pcioasis-stg"
    SIGN_UP_DOMAIN="labs.stg.pcioasis.com"
elif [ "$ENVIRONMENT" = "prd" ] || [ "$ENVIRONMENT" = "production" ]; then
    ENVIRONMENT="prd"
    FIREBASE_PROJECT_ID="ui-firebase-pcioasis-prd"
    SIGN_UP_DOMAIN="labs.pcioasis.com"
else
    print_error "Invalid environment: $ENVIRONMENT (must be 'stg' or 'prd')"
    exit 1
fi

SERVICE_ACCOUNT_KEY="${REPO_ROOT}/deploy/labs-auth-validator-${ENVIRONMENT}-key.json"

# Check if user ID provided
if [ -z "$USER_ID" ]; then
    print_error "User ID is required"
    echo "Usage: $0 <user-id> [environment]"
    echo "Example: $0 abc123xyz prd"
    exit 1
fi

# Check if service account key exists
if [ ! -f "$SERVICE_ACCOUNT_KEY" ]; then
    print_error "Service account key not found: $SERVICE_ACCOUNT_KEY"
    print_info "Run ${SCRIPT_DIR}/create-firebase-service-account.sh first"
    exit 1
fi

# Check if Node.js is available (for Firebase Admin SDK)
if ! command -v node &> /dev/null; then
    print_error "Node.js is required but not installed"
    print_info "Install Node.js to use Firebase Admin SDK"
    exit 1
fi

print_header "Setting Custom Claims for Labs User"
print_info "User ID: $USER_ID"
print_info "Environment: $ENVIRONMENT"
print_info "Firebase Project: $FIREBASE_PROJECT_ID"
print_info "Sign-up Domain: $SIGN_UP_DOMAIN"
echo ""

# Create temporary Node.js script to set custom claims
TEMP_SCRIPT=$(mktemp)
# Convert to absolute path for Node.js require
SERVICE_ACCOUNT_KEY_ABS=$(cd "$(dirname "$SERVICE_ACCOUNT_KEY")" && pwd)/$(basename "$SERVICE_ACCOUNT_KEY")
cat > "$TEMP_SCRIPT" <<EOF
const admin = require('firebase-admin');
const serviceAccount = require('$SERVICE_ACCOUNT_KEY_ABS');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: '$FIREBASE_PROJECT_ID'
});

const userId = '$USER_ID';
const customClaims = {
  sign_up_domain: '$SIGN_UP_DOMAIN',
  websiteAccess: ['labs']
};

admin.auth().setCustomUserClaims(userId, customClaims)
  .then(() => {
    console.log('✅ Custom claims set successfully');
    console.log('Claims:', JSON.stringify(customClaims, null, 2));
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error setting custom claims:', error.message);
    process.exit(1);
  });
EOF

# Check if firebase-admin is installed
if ! node -e "require('firebase-admin')" &> /dev/null; then
    print_status "Installing firebase-admin package..."
    npm install firebase-admin --no-save || {
        print_error "Failed to install firebase-admin"
        rm -f "$TEMP_SCRIPT"
        exit 1
    }
fi

# Run the script
print_status "Setting custom claims..."
node "$TEMP_SCRIPT"

# Cleanup
rm -f "$TEMP_SCRIPT"

print_header "Custom Claims Set Successfully"
print_info "User $USER_ID now has custom claims:"
print_info "  - sign_up_domain: $SIGN_UP_DOMAIN"
print_info "  - websiteAccess: ['labs']"
echo ""
print_info "Note: User may need to sign out and sign in again for claims to take effect"

