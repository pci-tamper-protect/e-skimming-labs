#!/bin/bash
# Helper script to run docker-compose with dotenvx-encrypted .env.stg
# Usage: ./deploy/docker-compose-auth.sh [docker-compose-args]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Check prerequisites
if [ ! -f .env.keys.stg ]; then
    echo "❌ Error: .env.keys.stg not found in project root"
    echo "   This file should be committed to git for staging"
    echo "   If missing, run: git pull"
    exit 1
fi

if [ ! -f .env.stg ]; then
    echo "❌ Error: .env.stg not found in project root"
    exit 1
fi

# Check if dotenvx is installed
if ! command -v dotenvx &> /dev/null; then
    echo "❌ Error: dotenvx not found"
    echo "   Install with: npm install -g @dotenvx/dotenvx"
    exit 1
fi

echo "🔓 Decrypting .env.stg and running docker-compose with authentication..."

# Decrypt .env.stg to a temporary file and source it
# This ensures all encrypted values are properly decrypted
TEMP_ENV=$(mktemp)
trap "rm -f $TEMP_ENV" EXIT

# Use dotenvx decrypt with explicit key file
dotenvx decrypt --env-file=.env.stg --env-keys-file=.env.keys.stg --stdout > "$TEMP_ENV" 2>/dev/null || {
    echo "❌ Error: Failed to decrypt .env.stg"
    echo "   Check that .env.keys.stg contains the correct private key"
    rm -f "$TEMP_ENV"
    exit 1
}

# Source the decrypted file to export all variables
# Parse the file and export variables, handling JSON values correctly
set -a  # Automatically export all variables
while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    # Skip dotenvx metadata lines
    [[ "$line" =~ ^DOTENV_ ]] && [[ ! "$line" =~ ^FIREBASE_ ]] && continue

    # Extract key and value
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"

        # Remove surrounding quotes if present
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi

        # Export the variable
        export "$key=$value"
    fi
done < "$TEMP_ENV"
set +a

# Set defaults for auth flags (these can be overridden)
export ENABLE_AUTH=${ENABLE_AUTH:-true}
export REQUIRE_AUTH=${REQUIRE_AUTH:-true}

# Clean up temp file
rm -f "$TEMP_ENV"
trap - EXIT

echo "✅ Decrypted environment variables loaded"
echo "   FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID:-not set}"
echo "   ENABLE_AUTH: $ENABLE_AUTH"
echo "   REQUIRE_AUTH: $REQUIRE_AUTH"
if [ -n "$FIREBASE_SERVICE_ACCOUNT_KEY" ]; then
    echo "   FIREBASE_SERVICE_ACCOUNT_KEY: [set, ${#FIREBASE_SERVICE_ACCOUNT_KEY} chars]"
else
    echo "   FIREBASE_SERVICE_ACCOUNT_KEY: [not set]"
fi
if [ -n "$FIREBASE_API_KEY" ]; then
    echo "   FIREBASE_API_KEY: [set]"
else
    echo "   FIREBASE_API_KEY: [not set]"
fi
echo ""

# Run docker-compose with decrypted environment variables
echo "🚀 Starting docker-compose with authentication..."
docker-compose -f docker-compose.yml -f docker-compose.auth.yml "$@"
