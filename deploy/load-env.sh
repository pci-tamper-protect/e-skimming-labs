#!/bin/bash
# Shared helper to load environment variables using dotenvx
# Source this file from other deploy scripts: source "$(dirname "$0")/load-env.sh"

# Get the directory where THIS script (load-env.sh) is located
# BASH_SOURCE[0] is this file, even when sourced
LOAD_ENV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get repo root (one level up from deploy/)
REPO_ROOT="$(cd "$LOAD_ENV_SCRIPT_DIR/.." && pwd)"

# Debug: show paths
# echo "DEBUG: LOAD_ENV_SCRIPT_DIR=$LOAD_ENV_SCRIPT_DIR"
# echo "DEBUG: REPO_ROOT=$REPO_ROOT"

# Check for dotenvx
if ! command -v dotenvx &> /dev/null; then
    echo "❌ dotenvx is not installed. Please install it first:"
    echo "   brew install dotenvx/brew/dotenvx"
    echo "   or: curl -sfS https://dotenvx.sh | sh"
    exit 1
fi

# Determine which env file to use and its corresponding keys file
ENV_FILE=""
KEYS_FILE=""
if [ -f "$REPO_ROOT/.env" ]; then
    if [ -L "$REPO_ROOT/.env" ]; then
        TARGET=$(readlink "$REPO_ROOT/.env")
        echo "📋 Using .env -> $TARGET"
        # Derive keys file from target (e.g., .env.stg -> .env.keys.stg)
        KEYS_FILE="$REPO_ROOT/.env.keys.${TARGET#.env.}"
    else
        echo "📋 Using .env"
        KEYS_FILE="$REPO_ROOT/.env.keys"
    fi
    ENV_FILE="$REPO_ROOT/.env"
elif [ -f "$REPO_ROOT/.env.stg" ]; then
    echo "📋 Using .env.stg from repo root (create symlink: ln -s .env.stg .env)"
    ENV_FILE="$REPO_ROOT/.env.stg"
    KEYS_FILE="$REPO_ROOT/.env.keys.stg"
elif [ -f "$REPO_ROOT/.env.prd" ]; then
    echo "📋 Using .env.prd from repo root (create symlink: ln -s .env.prd .env)"
    ENV_FILE="$REPO_ROOT/.env.prd"
    KEYS_FILE="$REPO_ROOT/.env.keys.prd"
else
    echo "❌ .env file not found in repo root: $REPO_ROOT"
    echo ""
    echo "Please create a .env file in the repo root with the following variables:"
    echo "  LABS_PROJECT_ID=labs-prd"
    echo "  LABS_REGION=us-central1"
    echo ""
    echo "You can either:"
    echo "  1. Create .env.prd or .env.stg in repo root with your values"
    echo "  2. Create a symlink in repo root: ln -s .env.prd .env (or ln -s .env.stg .env)"
    echo "  3. Or create .env directly in repo root"
    exit 1
fi

# Check if keys file exists for decryption
if [ ! -f "$KEYS_FILE" ]; then
    echo "⚠️  Keys file not found: $KEYS_FILE"
    echo "   Attempting to load without decryption (unencrypted values only)..."
    KEYS_FILE=""
fi

# Use dotenvx to decrypt and export environment variables
# This handles both encrypted (dotenvx) and plain .env files
echo "🔐 Loading environment with dotenvx..."

# Build dotenvx command with optional keys file
DOTENVX_CMD="dotenvx run --env-file=$ENV_FILE"
if [ -n "$KEYS_FILE" ]; then
    DOTENVX_CMD="$DOTENVX_CMD -fk $KEYS_FILE"
fi

# Export all environment variables from the .env file
# dotenvx run executes a command with the env vars loaded
# We use printenv to get all vars, filter for relevant ones, and export them
while IFS='=' read -r key value; do
    if [[ -n "$key" && ! "$key" =~ ^# ]]; then
        export "$key=$value"
    fi
done < <($DOTENVX_CMD -- printenv 2>/dev/null | grep -E '^(LABS_|HOME_|FIREBASE_|REGION=|GAR_)')

# Set LABS_REGION from REGION if not already set (for backward compatibility)
if [ -z "$LABS_REGION" ] && [ -n "$REGION" ]; then
    export LABS_REGION="$REGION"
fi

# Verify required variables are set
if [ -z "$LABS_PROJECT_ID" ]; then
    echo "❌ LABS_PROJECT_ID not set after loading .env"
    echo "   Make sure the .env file contains LABS_PROJECT_ID"
    exit 1
fi

echo "✅ Environment loaded: LABS_PROJECT_ID=$LABS_PROJECT_ID"
