#!/bin/sh
# Entrypoint script for home-index-service
# Creates symlink to correct environment file based on ENVIRONMENT variable

set -e

# Get environment (defaults to stg)
ENV="${ENVIRONMENT:-stg}"

# Create symlink to the appropriate .env file
# Note: .env files are copied from repo root during Docker build
if [ "$ENV" = "prd" ]; then
    if [ -f ".env.prd" ]; then
        echo "🔗 Linking .env.prd -> .env"
        ln -sf .env.prd .env
    else
        echo "⚠️  Warning: .env.prd not found, falling back to .env.stg"
        ln -sf .env.stg .env
    fi
else
    echo "🔗 Linking .env.stg -> .env"
    ln -sf .env.stg .env
fi

# Check if dotenvx key is mounted
if [ -f "/etc/secrets/dotenvx-key" ]; then
    # Extract the private key for the current environment from the keys file
    # For staging, look for DOTENV_PRIVATE_KEY_STG_SECRETS
    if [ "$ENV" = "prd" ]; then
        DOTENV_PRIVATE_KEY=$(grep -E "^DOTENV_PRIVATE_KEY_PRD_SECRETS=" /etc/secrets/dotenvx-key | cut -d'=' -f2)
    else
        DOTENV_PRIVATE_KEY=$(grep -E "^DOTENV_PRIVATE_KEY_STG_SECRETS=" /etc/secrets/dotenvx-key | cut -d'=' -f2)
    fi

    if [ -n "$DOTENV_PRIVATE_KEY" ]; then
        export DOTENV_PRIVATE_KEY
        echo "🔑 DOTENV_PRIVATE_KEY loaded from /etc/secrets/dotenvx-key (${#DOTENV_PRIVATE_KEY} chars)"
    else
        echo "⚠️  Warning: Could not extract DOTENV_PRIVATE_KEY from /etc/secrets/dotenvx-key"
    fi
else
    echo "⚠️  Warning: /etc/secrets/dotenvx-key not found, dotenvx may not work"
fi

# Run the application with dotenvx to decrypt environment variables
echo "🚀 Starting application with dotenvx..."
exec dotenvx run -- ./main
