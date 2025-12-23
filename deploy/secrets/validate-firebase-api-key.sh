#!/bin/bash
# Validate Firebase API Key from .env file
# This script checks if FIREBASE_API_KEY is valid by making a test API call to Firebase

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

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse environment argument (first positional argument)
if [ -n "$1" ]; then
    ENVIRONMENT="$1"
else
    ENVIRONMENT="${ENVIRONMENT:-stg}"
fi

# Normalize environment
if [ "$ENVIRONMENT" = "stg" ] || [ "$ENVIRONMENT" = "staging" ]; then
    ENVIRONMENT="stg"
elif [ "$ENVIRONMENT" = "prd" ] || [ "$ENVIRONMENT" = "production" ]; then
    ENVIRONMENT="prd"
else
    print_error "Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 [stg|prd]"
    echo "Example: $0 stg"
    echo "Example: $0 prd"
    exit 1
fi

ENV_FILE="${REPO_ROOT}/.env.${ENVIRONMENT}"
ENV_KEYS_FILE="${REPO_ROOT}/.env.keys.${ENVIRONMENT}"

# Check required tools
check_requirements() {
    print_header "Checking Requirements"

    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi

    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found: $ENV_FILE"
        exit 1
    fi

    print_status "All requirements met ✓"
}

# Load environment variables from .env file
load_env_vars() {
    print_header "Loading Environment Variables"

    # Check if file has encrypted values (dotenvx encrypts individual values, not the whole file)
    HAS_ENCRYPTED_VALUES=$(grep -q "^[A-Z_]*=encrypted:" "$ENV_FILE" 2>/dev/null && echo "yes" || echo "no")
    
    # Check if .env.keys file exists
    if [ -f "$ENV_KEYS_FILE" ] || [ "$HAS_ENCRYPTED_VALUES" = "yes" ]; then
        if [ "$HAS_ENCRYPTED_VALUES" = "yes" ]; then
            print_status "Encrypted values detected in .env file, using dotenvx to decrypt..."
        else
            print_status ".env.keys file found, using dotenvx (may have encrypted values)..."
        fi

        # Check if dotenvx is installed
        if ! command -v dotenvx &> /dev/null; then
            print_error "dotenvx is required to decrypt .env file but not installed"
            echo "Install it with: npm install -g @dotenvx/dotenvx"
            exit 1
        fi

        # Check if .env.keys file exists
        if [ ! -f "$ENV_KEYS_FILE" ]; then
            print_error ".env.keys file not found: $ENV_KEYS_FILE"
            echo "This file is required to decrypt encrypted values in .env.${ENVIRONMENT}"
            exit 1
        fi

        # Use dotenvx get to decrypt individual variables (same approach as manual command)
        print_status "Decrypting with dotenvx..."
        
        # Get FIREBASE_API_KEY
        FIREBASE_API_KEY=$(dotenvx get FIREBASE_API_KEY -f "$ENV_FILE" -fk "$ENV_KEYS_FILE" 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$FIREBASE_API_KEY" ]; then
            print_error "Failed to decrypt FIREBASE_API_KEY with dotenvx"
            print_info "Make sure:"
            echo "  1. The .env.keys.${ENVIRONMENT} file contains the correct decryption key"
            echo "  2. The encrypted values in .env.${ENVIRONMENT} are properly formatted"
            exit 1
        fi
        
        # Get FIREBASE_PROJECT_ID
        FIREBASE_PROJECT_ID=$(dotenvx get FIREBASE_PROJECT_ID -f "$ENV_FILE" -fk "$ENV_KEYS_FILE" 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$FIREBASE_PROJECT_ID" ]; then
            print_error "Failed to decrypt FIREBASE_PROJECT_ID with dotenvx"
            exit 1
        fi
        
        # Trim any whitespace
        FIREBASE_API_KEY=$(echo "$FIREBASE_API_KEY" | xargs)
        FIREBASE_PROJECT_ID=$(echo "$FIREBASE_PROJECT_ID" | xargs)
        
        # Export for use in script
        export FIREBASE_API_KEY
        export FIREBASE_PROJECT_ID
        
        print_status "Variables decrypted successfully"
    else
        # File has no encrypted values and no .env.keys, source it directly
        print_status "No encrypted values detected, loading .env file directly..."
        set -a
        source "$ENV_FILE"
        set +a
    fi

    # Trim whitespace from variables
    FIREBASE_API_KEY=$(echo "$FIREBASE_API_KEY" | xargs)
    FIREBASE_PROJECT_ID=$(echo "$FIREBASE_PROJECT_ID" | xargs)

    # Check if required variables are set
    if [ -z "$FIREBASE_API_KEY" ] || [ "$FIREBASE_API_KEY" = "" ]; then
        print_error "FIREBASE_API_KEY not found or empty in $ENV_FILE"
        print_info "Checking if key is encrypted..."
        if grep -q "^FIREBASE_API_KEY=encrypted:" "$ENV_FILE" 2>/dev/null; then
            print_info "Key appears to be encrypted. Make sure .env.keys.${ENVIRONMENT} exists and contains the decryption key."
        fi
        exit 1
    fi

    if [ -z "$FIREBASE_PROJECT_ID" ] || [ "$FIREBASE_PROJECT_ID" = "" ]; then
        print_error "FIREBASE_PROJECT_ID not found or empty in $ENV_FILE"
        echo "Note: FIREBASE_PROJECT_ID is required to validate the API key"
        exit 1
    fi

    # Check if API key still looks encrypted
    if echo "$FIREBASE_API_KEY" | grep -q "^encrypted:"; then
        print_error "FIREBASE_API_KEY appears to still be encrypted!"
        print_info "The key should start with a string like 'AIza...' not 'encrypted:'"
        print_info "Make sure dotenvx is properly decrypting the file."
        exit 1
    fi

    print_status "Environment variables loaded ✓"
    print_info "Firebase Project ID: $FIREBASE_PROJECT_ID"
    print_info "Firebase API Key (first 10 chars): ${FIREBASE_API_KEY:0:10}"
    print_info "API Key length: ${#FIREBASE_API_KEY} characters"
}

# Validate Firebase API key by making a test API call
validate_api_key() {
    print_header "Validating Firebase API Key"

    # Check if Node.js is available
    if ! command -v node &> /dev/null; then
        print_error "Node.js is required for Firebase API key validation"
        print_info "Install Node.js: https://nodejs.org/"
        exit 1
    fi

    # Use Node.js script with Firebase SDK for validation
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    JS_SCRIPT="${SCRIPT_DIR}/validate-firebase-api-key.js"
    
    if [ ! -f "$JS_SCRIPT" ]; then
        print_error "JavaScript validation script not found: $JS_SCRIPT"
        exit 1
    fi

    # Check if firebase package is installed
    if [ ! -d "${REPO_ROOT}/node_modules/firebase" ]; then
        print_error "Firebase SDK not found in node_modules"
        print_info "Install it with: cd ${REPO_ROOT} && npm install firebase"
        exit 1
    fi

    print_status "Using Firebase JavaScript SDK for validation..."
    print_info "Method: Firebase Web SDK (firebase/app, firebase/auth)"
    print_info "Project ID: $FIREBASE_PROJECT_ID"
    print_info "API Key (first 20 chars): ${FIREBASE_API_KEY:0:20}..."

    # Run the Node.js validation script from repo root so it can find node_modules
    cd "$REPO_ROOT"
    if node "$JS_SCRIPT" "$FIREBASE_API_KEY" "$FIREBASE_PROJECT_ID"; then
        print_success "Firebase API key validation passed!"
        return 0
    else
        EXIT_CODE=$?
        print_error "Firebase API key validation failed (exit code: $EXIT_CODE)"
        exit $EXIT_CODE
    fi
}

# Main execution
main() {
    print_header "Firebase API Key Validation"
    print_info "Environment: $ENVIRONMENT"
    print_info "Env file: $ENV_FILE"
    echo ""

    check_requirements
    load_env_vars
    validate_api_key

    echo ""
    print_header "Validation Complete"
    print_success "Firebase API key is valid and working correctly!"
}

# Run main function
main "$@"

