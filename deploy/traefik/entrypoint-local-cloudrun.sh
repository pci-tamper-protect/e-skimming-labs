#!/bin/bash
# Entrypoint for local Traefik with Cloud Run provider
# Handles environment variable substitution in config file and starts Traefik

set -e

# Write directly to container logs
LOG_FD=/proc/1/fd/1
if [ ! -w "$LOG_FD" ]; then
  LOG_FD=/proc/1/fd/2
fi

# Function to log with timestamp
log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >&2
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" > "$LOG_FD" 2>/dev/null || true
}

# Ensure all output goes to stderr so logs are captured
exec 1>&2

log "🚀 Starting Traefik with Cloud Run provider (local development mode)..."
log "Environment: ${ENVIRONMENT:-local-cloudrun}"
log "LABS_PROJECT_ID: ${LABS_PROJECT_ID:-<not set>}"
log "HOME_PROJECT_ID: ${HOME_PROJECT_ID:-<not set>}"
log "REGION: ${REGION:-us-central1}"
log "TRAEFIK_LOCAL_ONLY_PORT: ${TRAEFIK_LOCAL_ONLY_PORT:-8084}"
log "TRAEFIK_LOCAL_ONLY_DASHBOARD_PORT: ${TRAEFIK_LOCAL_ONLY_DASHBOARD_PORT:-8085}"
log "Current user: $(whoami) (UID: $(id -u), GID: $(id -g))"

# Verify required tools are available
log "Verifying required tools are installed..."
if command -v go >/dev/null 2>&1; then
  GO_VERSION=$(go version 2>&1 || echo "unknown")
  log "✅ Go is available: $GO_VERSION"
else
  log "❌ ERROR: Go is not available in PATH"
  exit 1
fi

# Check if envsubst is available (for environment variable substitution)
if command -v envsubst >/dev/null 2>&1; then
  log "✅ envsubst is available for config substitution"
  USE_ENVSUBST=true
else
  log "⚠️  WARNING: envsubst not available, using sed for substitution"
  USE_ENVSUBST=false
fi

# Create dynamic config directory if it doesn't exist
log "Creating /etc/traefik/dynamic directory..."
mkdir -p /etc/traefik/dynamic || {
  log "ERROR: Failed to create /etc/traefik/dynamic"
  exit 1
}

# Verify required environment variables
if [ -z "$LABS_PROJECT_ID" ]; then
  log "❌ ERROR: LABS_PROJECT_ID environment variable is required"
  exit 1
fi

# Verify ADC credentials are available
if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  log "❌ ERROR: GOOGLE_APPLICATION_CREDENTIALS environment variable is required"
  exit 1
fi

if [ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  log "❌ ERROR: ADC credentials file not found: $GOOGLE_APPLICATION_CREDENTIALS"
  log "   Run: gcloud auth application-default login"
  exit 1
fi

log "✅ ADC credentials found at: $GOOGLE_APPLICATION_CREDENTIALS"

# Substitute environment variables in config file
# Original config is read-only (mounted volume), so we write to a temp location
CONFIG_FILE="/etc/traefik/traefik.yml"
CONFIG_ORIGINAL="$CONFIG_FILE"
CONFIG_SUBSTITUTED="/tmp/traefik.yml"

log "Substituting environment variables in config file..."
log "   Original: $CONFIG_ORIGINAL"
log "   Substituted: $CONFIG_SUBSTITUTED"

if [ "$USE_ENVSUBST" = true ]; then
  # Use sed to handle ${VAR:-default} syntax (envsubst doesn't support defaults)
  # First, set the actual values
  TRAEFIK_PORT="${TRAEFIK_LOCAL_ONLY_PORT:-8084}"
  TRAEFIK_DASHBOARD_PORT="${TRAEFIK_LOCAL_ONLY_DASHBOARD_PORT:-8085}"
  
  # Substitute ${VAR:-default} patterns with actual values
  sed "s/\${TRAEFIK_LOCAL_ONLY_PORT:-8084}/${TRAEFIK_PORT}/g" \
      "$CONFIG_ORIGINAL" | \
  sed "s/\${TRAEFIK_LOCAL_ONLY_DASHBOARD_PORT:-8085}/${TRAEFIK_DASHBOARD_PORT}/g" > \
      "$CONFIG_SUBSTITUTED" || {
    log "❌ ERROR: Failed to substitute environment variables in config"
    exit 1
  }
else
  # Fallback to sed for basic substitution
  TRAEFIK_PORT="${TRAEFIK_LOCAL_ONLY_PORT:-8084}"
  TRAEFIK_DASHBOARD_PORT="${TRAEFIK_LOCAL_ONLY_DASHBOARD_PORT:-8085}"
  sed "s/\${TRAEFIK_LOCAL_ONLY_PORT:-8084}/${TRAEFIK_PORT}/g" \
      "$CONFIG_ORIGINAL" | \
  sed "s/\${TRAEFIK_LOCAL_ONLY_DASHBOARD_PORT:-8085}/${TRAEFIK_DASHBOARD_PORT}/g" > \
      "$CONFIG_SUBSTITUTED" || {
    log "❌ ERROR: Failed to substitute environment variables in config"
    exit 1
  }
fi

# Use substituted config file
CONFIG_FILE="$CONFIG_SUBSTITUTED"
log "✅ Config file prepared with port ${TRAEFIK_LOCAL_ONLY_PORT:-8084} (web) and ${TRAEFIK_LOCAL_ONLY_DASHBOARD_PORT:-8085} (dashboard)"

# Verify config file exists and has experimental.localPlugins
if [ -f "$CONFIG_FILE" ]; then
  if grep -q "experimental:" "$CONFIG_FILE" && grep -q "localPlugins:" "$CONFIG_FILE"; then
    log "✅ Config file found with experimental.localPlugins"
  else
    log "⚠️  WARNING: Config file exists but missing experimental.localPlugins"
  fi
else
  log "❌ ERROR: Config file $CONFIG_FILE not found!"
  exit 1
fi

# Verify plugin directory exists
if [ -d "/plugins-local" ]; then
  log "✅ Plugin directory found at /plugins-local"
else
  log "⚠️  WARNING: Plugin directory not found at /plugins-local"
fi

log "✅ Configuration complete. Starting Traefik..."
log "   Plugin will discover services from projects: ${LABS_PROJECT_ID} ${HOME_PROJECT_ID}"
log "   Web traffic: http://localhost:${TRAEFIK_LOCAL_ONLY_PORT:-8084}"
log "   Dashboard: http://localhost:${TRAEFIK_LOCAL_ONLY_DASHBOARD_PORT:-8085}/dashboard/"
log "   Identity tokens will be injected via X-Serverless-Authorization header"

# Start Traefik with explicit config file path and DEBUG logging
exec "$@" --configFile="$CONFIG_FILE" --log.level=DEBUG
