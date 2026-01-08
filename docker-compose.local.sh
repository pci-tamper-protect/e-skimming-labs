#!/bin/bash
# Auto-loading wrapper for docker-compose that automatically decrypts .env.stg if available
# Usage: ./docker-compose.local.sh [docker-compose-args]
# This script uses dotenvx run to decrypt .env.stg on-the-fly for docker-compose

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if .env.stg exists and can be decrypted
if [ -f .env.stg ] && [ -f .env.keys.stg ]; then
    # Check if dotenvx is installed
    if command -v dotenvx &> /dev/null; then
        echo "🔓 Auto-detected .env.stg - using dotenvx to decrypt for docker-compose..."
        echo "   Using .env.keys.stg for decryption key"
        echo ""

        # Verify .env.keys.stg is readable
        if [ ! -r .env.keys.stg ]; then
            echo "❌ Error: .env.keys.stg exists but is not readable"
            exit 1
        fi

        # Verify docker-compose.auth.yml exists (contains volume mounts for .env.keys.stg)
        if [ ! -f docker-compose.auth.yml ]; then
            echo "❌ Error: docker-compose.auth.yml not found"
            echo "   This file is required to mount .env.keys.stg into containers"
            exit 1
        fi

        # Set default auth flags if not already set
        export ENABLE_AUTH=${ENABLE_AUTH:-true}
        export REQUIRE_AUTH=${REQUIRE_AUTH:-true}

        # Use dotenvx run to decrypt .env.stg and run docker-compose
        # dotenvx automatically decrypts .env.stg using .env.keys.stg and makes variables available to docker-compose
        # The --env-keys-file flag tells dotenvx where to find the decryption key
        # docker-compose.auth.yml mounts .env.keys.stg to /etc/secrets/dotenvx-key:ro in containers
        echo "   Mounting .env.keys.stg to containers via docker-compose.auth.yml"
        
        # Check if docker-compose.dev.yml exists and user wants dev mode
        if [ -f docker-compose.dev.yml ] && [[ "$*" == *"dev"* ]] || [ "${DEV_MODE:-false}" = "true" ]; then
            echo "   🚀 Development mode: Using docker-compose.dev.yml for hot-reload"
            dotenvx run --env-file=.env.stg --env-keys-file=.env.keys.stg -- \
                docker-compose -f docker-compose.yml -f docker-compose.auth.yml -f docker-compose.dev.yml "$@"
        else
            dotenvx run --env-file=.env.stg --env-keys-file=.env.keys.stg -- \
                docker-compose -f docker-compose.yml -f docker-compose.auth.yml "$@"
        fi
    else
        echo "⚠️  Warning: dotenvx not installed, running without Firebase auth"
        echo "   Install with: npm install -g @dotenvx/dotenvx"
        echo "   Or use: ./deploy/docker-compose-auth.sh"
        docker-compose "$@"
    fi
else
    # No .env.stg found, run normally
    echo "ℹ️  No .env.stg found, running without Firebase auth"
    
    # Check if docker-compose.dev.yml exists and user wants dev mode
    if [ -f docker-compose.dev.yml ] && [[ "$*" == *"dev"* ]] || [ "${DEV_MODE:-false}" = "true" ]; then
        echo "   🚀 Development mode: Using docker-compose.dev.yml for hot-reload"
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml "$@"
    else
        docker-compose "$@"
    fi
fi
