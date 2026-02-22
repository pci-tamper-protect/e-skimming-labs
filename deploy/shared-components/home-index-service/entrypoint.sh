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
    # Extract the private key for the current environment from the keys file.
    # dotenvx matches key names: .env.prd uses DOTENV_PUBLIC_KEY_PRD, so needs DOTENV_PRIVATE_KEY_PRD.
    # Supports two secret formats:
    #   1. Standard: DOTENV_PRIVATE_KEY_PRD=<hex>  (preferred, extract value after =)
    #   2. Bare key: just the raw <hex> key on its own line  (Secret Manager bare-key variant)
    ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
    KEY_VAR="DOTENV_PRIVATE_KEY_${ENV_UPPER}"  # e.g. DOTENV_PRIVATE_KEY_PRD or DOTENV_PRIVATE_KEY_STG

    KEY_VALUE=$(grep -E "^${KEY_VAR}=" /etc/secrets/dotenvx-key | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ -z "$KEY_VALUE" ]; then
        # No NAME=VALUE line found - try treating the whole file as a bare key
        RAW=$(tr -d '[:space:]' < /etc/secrets/dotenvx-key)
        case "$RAW" in
            *=*) ;; # Has KEY=VALUE pairs but not our key - leave empty
            *)   KEY_VALUE="$RAW"
                 echo "🔑 ${KEY_VAR} extracted from bare-key secret format" ;;
        esac
    fi

    if [ -n "$KEY_VALUE" ]; then
        # Export with the env-specific name (e.g. DOTENV_PRIVATE_KEY_PRD) so dotenvx
        # can match it to DOTENV_PUBLIC_KEY_PRD inside .env.prd.
        export "${KEY_VAR}=${KEY_VALUE}"
        echo "🔑 ${KEY_VAR} loaded from /etc/secrets/dotenvx-key (${#KEY_VALUE} chars)"
    else
        echo "⚠️  Warning: Could not extract ${KEY_VAR} from /etc/secrets/dotenvx-key"
    fi
else
    echo "⚠️  Warning: /etc/secrets/dotenvx-key not found, dotenvx may not work"
fi

# Run the application with dotenvx to decrypt environment variables
echo "🚀 Starting application with dotenvx..."
exec dotenvx run -- ./main
