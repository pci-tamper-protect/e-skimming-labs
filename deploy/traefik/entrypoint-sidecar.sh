#!/bin/sh
# Entrypoint script for Traefik sidecar container
# Provides better logging for startup debugging

set -e

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

log "🚀 Starting Traefik sidecar container..."

# Verify config file exists
if [ ! -f /etc/traefik/traefik.yml ]; then
  log "❌ ERROR: Config file not found: /etc/traefik/traefik.yml"
  exit 1
fi
log "✅ Config file found: /etc/traefik/traefik.yml"

# Verify shared volume mount
if [ ! -d /shared/traefik/dynamic ]; then
  log "❌ ERROR: Shared volume not mounted: /shared/traefik/dynamic"
  exit 1
fi
log "✅ Shared volume mounted: /shared/traefik/dynamic"

# Copy static middlewares to shared volume (provider generates routes, this provides middlewares)
# The middlewares file defines strip-prefix, retry-cold-start, auth-check, etc.
if [ -f /etc/traefik/dynamic/middlewares.yml ]; then
  log "📋 Copying static middlewares to shared volume..."
  cp /etc/traefik/dynamic/middlewares.yml /shared/traefik/dynamic/middlewares.yml
  log "✅ Middlewares copied to /shared/traefik/dynamic/middlewares.yml"
fi

# Check if routes.yml exists (may not exist initially - provider will create it)
# Note: Route generation is handled by the traefik-cloudrun-provider sidecar
if [ -f /shared/traefik/dynamic/routes.yml ]; then
  log "✅ routes.yml found (size: $(stat -c%s /shared/traefik/dynamic/routes.yml 2>/dev/null || stat -f%z /shared/traefik/dynamic/routes.yml 2>/dev/null || echo 'unknown') bytes)"
else
  log "⚠️  routes.yml not found yet (provider will generate it)"
fi

# Verify we can write to shared volume
if touch /shared/traefik/dynamic/.test-write 2>/dev/null; then
  rm -f /shared/traefik/dynamic/.test-write
  log "✅ Can write to shared volume"
else
  log "❌ ERROR: Cannot write to shared volume"
  exit 1
fi

# Validate Traefik config before starting
log "🔍 Validating Traefik configuration..."
if ! traefik version >/dev/null 2>&1; then
  log "⚠️  WARNING: Cannot run 'traefik version' (may be normal)"
fi

# Check config syntax (Traefik v2.10)
log "🔍 Checking config file syntax..."
if traefik version >/dev/null 2>&1; then
  # Try to validate config (this will fail if config is invalid)
  if traefik --configfile=/etc/traefik/traefik.yml --checkconfig 2>&1 | grep -q "Configuration loaded"; then
    log "✅ Config file syntax is valid"
  else
    log "⚠️  Config validation check completed (may show warnings)"
  fi
fi

# Switch to traefik user for running Traefik (if we're root)
if [ "$(id -u)" = "0" ]; then
  log "🔄 Switching to traefik user..."
  # Explicitly pass config file and entrypoint to prevent default "http" entrypoint
  # Use --entrypoints.web.address to explicitly set the entrypoint
  exec su-exec traefik traefik --configfile=/etc/traefik/traefik.yml --entrypoints.web.address=0.0.0.0:8080 "$@"
else
  # Already traefik user, just start Traefik
  log "🚀 Starting Traefik..."
  log "   Config: /etc/traefik/traefik.yml"
  log "   Dynamic config: /shared/traefik/dynamic"
  log "   Entrypoint: web:8080"
  # Explicitly pass config file and entrypoint to prevent default "http" entrypoint
  # Use --entrypoints.web.address to explicitly set the entrypoint
  exec traefik --configfile=/etc/traefik/traefik.yml --entrypoints.web.address=0.0.0.0:8080 "$@"
fi
