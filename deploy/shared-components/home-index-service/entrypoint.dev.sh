#!/bin/sh
# Development entrypoint script for home-index-service
# Wraps the binary with dotenvx for environment variable decryption
# This is called by Air after each rebuild

set -e

# Get environment (defaults to local for dev)
ENV="${ENVIRONMENT:-local}"

# Create symlink to the appropriate .env file
# In dev mode, .env.stg should be mounted or available
if [ "$ENV" = "prd" ]; then
    if [ -f ".env.prd" ]; then
        echo "🔗 Linking .env.prd -> .env"
        ln -sf .env.prd .env
    else
        echo "⚠️  Warning: .env.prd not found, falling back to .env.stg"
        ln -sf .env.stg .env
    fi
else
    if [ -f ".env.stg" ]; then
        echo "🔗 Linking .env.stg -> .env"
        ln -sf .env.stg .env
    else
        echo "⚠️  Warning: .env.stg not found, running without encrypted env vars"
    fi
fi

# Check if dotenvx key is mounted
if [ -f "/etc/secrets/dotenvx-key" ]; then
    # Extract the private key for the current environment from the keys file
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
    echo "ℹ️  /etc/secrets/dotenvx-key not found, running without dotenvx decryption"
fi

# Run the application with dotenvx to decrypt environment variables
# Air builds to ./tmp/main, so we use that path
BINARY="./tmp/main"
if [ ! -f "$BINARY" ]; then
    echo "❌ Error: Binary not found at $BINARY"
    echo "   Make sure Air has built the binary"
    exit 1
fi
echo "🚀 Starting application: $BINARY"
exec dotenvx run -- "$BINARY"
