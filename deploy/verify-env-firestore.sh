#!/bin/bash
# Verify .env decryption and Firestore authentication
# Usage: ./deploy/verify-env-firestore.sh [stg|prd]
#
# This script:
# 1. Verifies .env.{env} can be decrypted using dotenvx
# 2. Validates Firebase service account JSON format
# 3. Tests Firestore connectivity using decrypted credentials

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse environment argument
ENVIRONMENT="${1:-stg}"
if [ "$ENVIRONMENT" != "stg" ] && [ "$ENVIRONMENT" != "prd" ]; then
    echo -e "${RED}❌ Error: Environment must be 'stg' or 'prd'${NC}"
    echo "Usage: $0 [stg|prd]"
    exit 1
fi

ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
ENV_FILE=".env.${ENVIRONMENT}"
KEYS_FILE=".env.keys.${ENVIRONMENT}"

cd "$PROJECT_ROOT"

echo -e "${BLUE}=== Verifying .env Decryption and Firestore Auth ===${NC}"
echo "Environment: ${ENVIRONMENT}"
echo ""

ERRORS=0

# 1. Check prerequisites
echo -e "${BLUE}1. Checking prerequisites...${NC}"

if ! command -v dotenvx &> /dev/null; then
    echo -e "${RED}   ❌ dotenvx not found${NC}"
    echo "   Install with: npm install -g @dotenvx/dotenvx"
    exit 1
fi
echo -e "${GREEN}   ✅ dotenvx installed${NC}"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}   ❌ $ENV_FILE not found${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ $ENV_FILE found${NC}"

if [ ! -f "$KEYS_FILE" ]; then
    echo -e "${RED}   ❌ $KEYS_FILE not found${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ $KEYS_FILE found${NC}"

# 2. Test decryption
echo ""
echo -e "${BLUE}2. Testing .env decryption...${NC}"

TEMP_DECRYPTED=$(mktemp)
trap "rm -f $TEMP_DECRYPTED" EXIT

if ! dotenvx decrypt -f "$ENV_FILE" -fk "$KEYS_FILE" --stdout > "$TEMP_DECRYPTED" 2>/dev/null; then
    echo -e "${RED}   ❌ Failed to decrypt $ENV_FILE${NC}"
    echo "   Check that $KEYS_FILE contains the correct private key"
    exit 1
fi
echo -e "${GREEN}   ✅ Decryption successful${NC}"

# 3. Extract Firebase credentials
echo ""
echo -e "${BLUE}3. Extracting Firebase credentials...${NC}"

# Source the decrypted file to get variables
set -a
while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    [[ "$line" =~ ^DOTENV_ ]] && continue
    
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        
        # Remove surrounding quotes if present
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi
        
        export "$key=$value"
    fi
done < "$TEMP_DECRYPTED"
set +a

# Extract Firebase-related variables
FIREBASE_SERVICE_ACCOUNT_KEY="${FIREBASE_SERVICE_ACCOUNT_KEY:-}"
APP_FIREBASE_API_KEY="${APP_FIREBASE_API_KEY:-}"
FIREBASE_API_KEY="${FIREBASE_API_KEY:-}"
FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}"
PROJECT_ID="${PROJECT_ID:-}"

# List all Firebase-related variables found
echo ""
echo -e "${BLUE}3. Firebase variables found in .env:${NC}"
FIREBASE_VARS=$(grep -E "^[A-Z_]*FIREBASE[A-Z_]*=" "$TEMP_DECRYPTED" | cut -d'=' -f1 | sort -u || echo "")
if [ -n "$FIREBASE_VARS" ]; then
    for var in $FIREBASE_VARS; do
        echo -e "${GREEN}   ✅ $var${NC}"
    done
else
    echo -e "${YELLOW}   ⚠️  No FIREBASE_* variables found${NC}"
fi

# Check for FIREBASE_SERVICE_ACCOUNT_KEY (required for Firestore)
if [ -z "$FIREBASE_SERVICE_ACCOUNT_KEY" ]; then
    echo -e "${YELLOW}   ⚠️  FIREBASE_SERVICE_ACCOUNT_KEY not set${NC}"
    echo "   Firestore connectivity test will be skipped"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}   ✅ FIREBASE_SERVICE_ACCOUNT_KEY found (${#FIREBASE_SERVICE_ACCOUNT_KEY} chars)${NC}"
fi

# Check for FIREBASE_API_KEY (for sign-in/sign-up pages)
if [ -z "$FIREBASE_API_KEY" ] && [ -n "$APP_FIREBASE_API_KEY" ]; then
    echo -e "${YELLOW}   ⚠️  FIREBASE_API_KEY not set, but APP_FIREBASE_API_KEY found${NC}"
    echo "   Note: Code expects FIREBASE_API_KEY for sign-in/sign-up pages"
    echo "   APP_FIREBASE_API_KEY may need to be mapped to FIREBASE_API_KEY in deploy scripts"
elif [ -z "$FIREBASE_API_KEY" ]; then
    echo -e "${YELLOW}   ⚠️  FIREBASE_API_KEY not set (optional for Firestore, required for sign-in)${NC}"
elif [ -n "$FIREBASE_API_KEY" ]; then
    echo -e "${GREEN}   ✅ FIREBASE_API_KEY found${NC}"
fi

if [ -z "$FIREBASE_PROJECT_ID" ]; then
    echo -e "${YELLOW}   ⚠️  FIREBASE_PROJECT_ID not set${NC}"
    # Try to infer from PROJECT_ID
    if [ -n "$PROJECT_ID" ]; then
        if [[ "$PROJECT_ID" == *"home"* ]]; then
            FIREBASE_PROJECT_ID="ui-firebase-pcioasis-${ENVIRONMENT}"
            echo -e "${BLUE}   ℹ️  Inferred FIREBASE_PROJECT_ID: $FIREBASE_PROJECT_ID${NC}"
        fi
    fi
else
    echo -e "${GREEN}   ✅ FIREBASE_PROJECT_ID: $FIREBASE_PROJECT_ID${NC}"
fi

# 4. Validate Firebase service account JSON (for Firestore)
if [ -n "$FIREBASE_SERVICE_ACCOUNT_KEY" ]; then
    echo ""
    echo -e "${BLUE}4. Validating Firebase service account JSON...${NC}"
    
    # Check if it's valid JSON
    if ! echo "$FIREBASE_SERVICE_ACCOUNT_KEY" | jq empty 2>/dev/null; then
        echo -e "${RED}   ❌ FIREBASE_SERVICE_ACCOUNT_KEY is not valid JSON${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}   ✅ Valid JSON format${NC}"
        
        # Extract project_id from JSON
        JSON_PROJECT_ID=$(echo "$FIREBASE_SERVICE_ACCOUNT_KEY" | jq -r '.project_id // empty' 2>/dev/null || echo "")
        if [ -n "$JSON_PROJECT_ID" ]; then
            echo -e "${GREEN}   ✅ Service account project_id: $JSON_PROJECT_ID${NC}"
            # Note: Service account project_id may differ from FIREBASE_PROJECT_ID (e.g., labs-home-stg vs ui-firebase-pcioasis-stg)
            # This is expected - the service account from one project can access Firebase in another project
        fi
        
        # Check for required fields
        if echo "$FIREBASE_SERVICE_ACCOUNT_KEY" | jq -e '.private_key // empty' > /dev/null 2>&1; then
            echo -e "${GREEN}   ✅ Contains private_key${NC}"
        else
            echo -e "${RED}   ❌ Missing private_key field${NC}"
            ERRORS=$((ERRORS + 1))
        fi
        
        if echo "$FIREBASE_SERVICE_ACCOUNT_KEY" | jq -e '.client_email // empty' > /dev/null 2>&1; then
            CLIENT_EMAIL=$(echo "$FIREBASE_SERVICE_ACCOUNT_KEY" | jq -r '.client_email')
            echo -e "${GREEN}   ✅ Service account email: $CLIENT_EMAIL${NC}"
        else
            echo -e "${RED}   ❌ Missing client_email field${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
fi

# 5. Test Firestore connectivity
if [ -n "$FIREBASE_SERVICE_ACCOUNT_KEY" ] && [ -n "$FIREBASE_PROJECT_ID" ]; then
    echo ""
    echo -e "${BLUE}5. Testing Firestore connectivity...${NC}"
    
    # Write service account to temp file for gcloud
    TEMP_SA_FILE=$(mktemp)
    echo "$FIREBASE_SERVICE_ACCOUNT_KEY" > "$TEMP_SA_FILE"
    trap "rm -f $TEMP_DECRYPTED $TEMP_SA_FILE" EXIT
    
    # Test using gcloud with service account
    if command -v gcloud &> /dev/null; then
        # Activate service account temporarily
        if gcloud auth activate-service-account --key-file="$TEMP_SA_FILE" --quiet 2>/dev/null; then
            # Try to list Firestore databases (tests connectivity and permissions)
            if gcloud firestore databases list --project="$FIREBASE_PROJECT_ID" --format="value(name)" > /dev/null 2>&1; then
                echo -e "${GREEN}   ✅ Firestore connectivity test passed${NC}"
                DB_NAME=$(gcloud firestore databases list --project="$FIREBASE_PROJECT_ID" --format="value(name)" 2>/dev/null | head -1)
                if [ -n "$DB_NAME" ]; then
                    echo -e "${GREEN}   ✅ Found Firestore database: $DB_NAME${NC}"
                fi
            else
                # Check if it's a permission error (which means we connected)
                ERROR_OUTPUT=$(gcloud firestore databases list --project="$FIREBASE_PROJECT_ID" 2>&1)
                if echo "$ERROR_OUTPUT" | grep -qi "permission\|denied\|forbidden"; then
                    echo -e "${YELLOW}   ⚠️  Connected but permission denied (check IAM roles)${NC}"
                    echo "   Service account needs roles/datastore.user on project $FIREBASE_PROJECT_ID"
                else
                    echo -e "${RED}   ❌ Firestore connectivity test failed:${NC}"
                    echo "$ERROR_OUTPUT" | sed 's/^/      /'
                    ERRORS=$((ERRORS + 1))
                fi
            fi
            
            # Restore original auth (if we had one)
            # Note: This might fail if user wasn't authenticated before - that's OK
            gcloud auth application-default login --quiet 2>/dev/null || true
        else
            echo -e "${YELLOW}   ⚠️  Failed to activate service account${NC}"
            echo "   Service account JSON may be invalid or incomplete"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${YELLOW}   ⚠️  gcloud not found - skipping Firestore connectivity test${NC}"
        echo "   Install gcloud CLI to test Firestore connectivity"
    fi
    
    rm -f "$TEMP_SA_FILE"
else
    echo ""
    echo -e "${YELLOW}5. Skipping Firestore connectivity test (missing credentials)${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s)${NC}"
    exit 1
fi
