#!/bin/bash
# Helper script to run docker-compose with decrypted environment variables
# Usage: ./deploy/docker-compose-auth.sh [docker-compose-args...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Check if dotenvx is installed
if ! command -v dotenvx &> /dev/null; then
    echo "❌ Error: dotenvx is not installed"
    echo "Install it with: npm install -g @dotenvx/dotenvx"
    exit 1
fi

# Check if .env.keys.stg exists
if [ ! -f ".env.keys.stg" ]; then
    echo "❌ Error: .env.keys.stg not found in repository root"
    echo "This file is required to decrypt .env.stg"
    exit 1
fi

# Check if .env.stg exists
if [ ! -f ".env.stg" ]; then
    echo "❌ Error: .env.stg not found in repository root"
    exit 1
fi

echo "🔐 Decrypting environment variables from .env.stg..."

# Export DOTENV_PRIVATE_KEY from .env.keys.stg
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"

# Use dotenvx to decrypt .env.stg and run docker-compose
# dotenvx run will decrypt the file and make variables available to the command
dotenvx run --env-file=.env.stg -- docker-compose -f docker-compose.yml -f docker-compose.auth.yml "$@"

