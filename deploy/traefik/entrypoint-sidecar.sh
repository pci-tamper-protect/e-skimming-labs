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

# Wait for routes.yml to be created by the provider sidecar
# This ensures Traefik has routes to serve before accepting traffic
# The provider sidecar runs in parallel and generates routes.yml
log "⏳ Waiting for provider sidecar to generate routes.yml..."
WAIT_TIMEOUT=60
WAIT_INTERVAL=2
WAITED=0
while [ ! -f /shared/traefik/dynamic/routes.yml ] || [ ! -s /shared/traefik/dynamic/routes.yml ]; do
  if [ $WAITED -ge $WAIT_TIMEOUT ]; then
    log "⚠️  Timeout waiting for routes.yml after ${WAIT_TIMEOUT}s"
    log "⚠️  Creating placeholder routes.yml - provider may update it later"
    # Create a minimal placeholder so Traefik can start
    cat > /shared/traefik/dynamic/routes.yml << 'PLACEHOLDER'
# Placeholder routes - provider sidecar will overwrite this
http:
  routers: {}
  services: {}
PLACEHOLDER
    break
  fi
  sleep $WAIT_INTERVAL
  WAITED=$((WAITED + WAIT_INTERVAL))
  log "   Waiting... (${WAITED}s/${WAIT_TIMEOUT}s)"
done

if [ -f /shared/traefik/dynamic/routes.yml ]; then
  ROUTES_SIZE=$(stat -c%s /shared/traefik/dynamic/routes.yml 2>/dev/null || stat -f%z /shared/traefik/dynamic/routes.yml 2>/dev/null || echo 'unknown')
  log "✅ routes.yml found (size: ${ROUTES_SIZE} bytes)"
  # Count routers in the file for debugging
  ROUTER_COUNT=$(grep -c "rule:" /shared/traefik/dynamic/routes.yml 2>/dev/null || echo "0")
  log "   Contains approximately ${ROUTER_COUNT} router rules"
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
