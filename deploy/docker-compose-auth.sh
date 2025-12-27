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

echo "🔓 Decrypting .env.stg and extracting environment variables..."

# Set decryption key
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"

# Extract environment variables from encrypted .env.stg
# Using dotenvx run to decrypt and extract specific vars
# Use a subshell to capture only the variable value, filtering out dotenvx output
FIREBASE_SERVICE_ACCOUNT_KEY=$(dotenvx run --env-file=.env.stg -- sh -c 'printenv FIREBASE_SERVICE_ACCOUNT_KEY' 2>/dev/null | tail -1 || echo "")
FIREBASE_API_KEY=$(dotenvx run --env-file=.env.stg -- sh -c 'printenv FIREBASE_API_KEY' 2>/dev/null | tail -1 || echo "")
FIREBASE_PROJECT_ID=$(dotenvx run --env-file=.env.stg -- sh -c 'printenv FIREBASE_PROJECT_ID' 2>/dev/null | tail -1 || echo "ui-firebase-pcioasis-stg")

# Export for docker-compose
export FIREBASE_SERVICE_ACCOUNT_KEY
export FIREBASE_API_KEY
export FIREBASE_PROJECT_ID

# Set defaults
export ENABLE_AUTH=${ENABLE_AUTH:-true}
export REQUIRE_AUTH=${REQUIRE_AUTH:-true}

if [ -z "$FIREBASE_SERVICE_ACCOUNT_KEY" ]; then
    echo "⚠️  Warning: FIREBASE_SERVICE_ACCOUNT_KEY not found in .env.stg"
    echo "   Auth will be disabled (service account JSON required for token validation)"
    export ENABLE_AUTH=false
fi

echo "✅ Environment variables loaded:"
echo "   FIREBASE_PROJECT_ID: $FIREBASE_PROJECT_ID"
echo "   ENABLE_AUTH: $ENABLE_AUTH"
echo "   REQUIRE_AUTH: $REQUIRE_AUTH"
if [ -n "$FIREBASE_SERVICE_ACCOUNT_KEY" ]; then
    echo "   FIREBASE_SERVICE_ACCOUNT_KEY: [set]"
else
    echo "   FIREBASE_SERVICE_ACCOUNT_KEY: [not set]"
fi
if [ -n "$FIREBASE_API_KEY" ]; then
    echo "   FIREBASE_API_KEY: [set]"
else
    echo "   FIREBASE_API_KEY: [not set]"
fi
echo ""

# Run docker-compose with both files
echo "🚀 Starting docker-compose with authentication..."
docker-compose -f docker-compose.yml -f docker-compose.auth.yml "$@"
