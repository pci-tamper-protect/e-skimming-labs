#!/bin/sh
# Startup script to set up dotenvx and run application with dotenvx
# Usage: ./dotenvx-startup.sh <command> [args...]
# Example: ./dotenvx-startup.sh ./analytics-service

set -e

# Get environment from ENVIRONMENT env var (set by Cloud Run)
ENV="${ENVIRONMENT:-prd}"

# Normalize environment name
if [ "$ENV" = "stg" ] || [ "$ENV" = "staging" ]; then
    ENV="stg"
elif [ "$ENV" = "prd" ] || [ "$ENV" = "production" ]; then
    ENV="prd"
fi

# Path where the secret is mounted by Cloud Run
MOUNTED_KEY="/etc/secrets/dotenvx-key"

# Application working directory (where .env files should be)
APP_DIR="${APP_DIR:-/app}"

cd "$APP_DIR"

echo "Setting up dotenvx for ${ENV} environment..."

# Check if mounted key exists and read it into DOTENV_PRIVATE_KEY
if [ -f "$MOUNTED_KEY" ]; then
    echo "Reading dotenvx private key from ${MOUNTED_KEY}..."
    export DOTENV_PRIVATE_KEY="$(cat "$MOUNTED_KEY")"
    echo "✅ DOTENV_PRIVATE_KEY environment variable set"
else
    echo "⚠️  Warning: Mounted dotenvx key not found at ${MOUNTED_KEY}"
    echo "   Secret may not be mounted, or mount path is incorrect"
    echo "   Running without dotenvx (using environment variables only)..."
    # Execute command without dotenvx
    exec "$@"
fi

# If encrypted .env file exists, symlink it to .env
# dotenvx will automatically decrypt when it sees both .env.<env> and DOTENV_PRIVATE_KEY
if [ -f ".env.${ENV}" ]; then
    if [ -f ".env" ] || [ -L ".env" ]; then
        rm -f ".env"
    fi
    
    echo "Creating symlink: .env -> .env.${ENV}"
    ln -sf ".env.${ENV}" ".env"
    echo "✅ .env symlink created"
fi

echo "✅ Dotenvx setup complete. Running with dotenvx..."

# Check if dotenvx is installed
if ! command -v dotenvx &> /dev/null; then
    echo "⚠️  Warning: dotenvx CLI not found, installing..."
    npm install -g @dotenvx/dotenvx || {
        echo "❌ Error: Failed to install dotenvx"
        echo "Running without dotenvx..."
        exec "$@"
    }
fi

# Run the command with dotenvx
# dotenvx will automatically decrypt .env.<env> using DOTENV_PRIVATE_KEY
exec dotenvx run -- "$@"

