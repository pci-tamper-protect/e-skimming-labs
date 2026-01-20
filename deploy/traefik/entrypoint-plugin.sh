#!/bin/bash
# Simplified entrypoint for Traefik with Cloud Run plugin
# The plugin handles all route generation, so we just need to ensure directories exist

set -e

# Write directly to Cloud Run logs via /proc/1/fd/1 (container's stdout)
LOG_FD=/proc/1/fd/1
if [ ! -w "$LOG_FD" ]; then
  # Fallback to stderr
  LOG_FD=/proc/1/fd/2
fi

# Function to log with timestamp
log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >&2
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" > "$LOG_FD" 2>/dev/null || true
}

# Ensure all output goes to stderr so Cloud Run captures it
exec 1>&2

log "🚀 Starting Traefik with Cloud Run plugin..."
log "Environment: ${ENVIRONMENT:-local}"
log "LABS_PROJECT_ID: ${LABS_PROJECT_ID:-<not set>}"
log "HOME_PROJECT_ID: ${HOME_PROJECT_ID:-<not set>}"
log "REGION: ${REGION:-us-central1}"
log "Current user: $(whoami) (UID: $(id -u), GID: $(id -g))"

# Verify required tools are available
log "Verifying required tools are installed..."
if command -v go >/dev/null 2>&1; then
  GO_VERSION=$(go version 2>&1 || echo "unknown")
  log "✅ Go is available: $GO_VERSION"
  log "   Go path: $(which go)"
else
  log "❌ ERROR: Go is not available in PATH"
  log "   PATH: $PATH"
  exit 1
fi

if command -v curl >/dev/null 2>&1; then
  log "✅ curl is available: $(curl --version 2>&1 | head -1)"
else
  log "⚠️  WARNING: curl is not available (may affect health checks)"
fi

if command -v bash >/dev/null 2>&1; then
  log "✅ bash is available: $(bash --version 2>&1 | head -1)"
else
  log "❌ ERROR: bash is not available"
  exit 1
fi

# Create dynamic config directory if it doesn't exist (for file provider middlewares)
log "Creating /etc/traefik/dynamic directory..."
mkdir -p /etc/traefik/dynamic || {
  log "ERROR: Failed to create /etc/traefik/dynamic"
  exit 1
}

# Ensure plugins-local directory exists and is readable
if [ -d "/plugins-local" ]; then
  log "✅ Plugin directory found at /plugins-local"
  log "   Plugin path: /plugins-local/src/github.com/pci-tamper-protect/traefik-cloudrun-provider"
else
  log "⚠️  WARNING: Plugin directory not found at /plugins-local"
  log "   Plugin may not load correctly"
fi

# Verify required environment variables
if [ -z "$LABS_PROJECT_ID" ]; then
  log "❌ ERROR: LABS_PROJECT_ID environment variable is required"
  exit 1
fi

log "✅ Configuration complete. Starting Traefik..."
log "   Plugin will discover services with traefik_enable=true label"
log "   Polling interval: 30s (configurable via pollInterval in traefik.yml)"
log "   Config file: /etc/traefik/traefik.yml"

# Verify config file exists and has experimental.localPlugins
if [ -f "/etc/traefik/traefik.yml" ]; then
  if grep -q "experimental:" /etc/traefik/traefik.yml && grep -q "localPlugins:" /etc/traefik/traefik.yml; then
    log "✅ Config file found with experimental.localPlugins"
  else
    log "⚠️  WARNING: Config file exists but missing experimental.localPlugins"
    log "   Config file content (first 30 lines):"
    head -30 /etc/traefik/traefik.yml | sed 's/^/      /' | while IFS= read -r line; do log "   $line"; done
  fi
else
  log "❌ ERROR: Config file /etc/traefik/traefik.yml not found!"
  exit 1
fi

# Start Traefik with explicit config file path and DEBUG logging
# This ensures Traefik uses our config file, not any default from base image
# Also explicitly set DEBUG log level via command line (redundant with config file, but ensures it's set)
exec "$@" --configFile=/etc/traefik/traefik.yml --log.level=DEBUG
