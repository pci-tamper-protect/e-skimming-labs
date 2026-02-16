#!/bin/sh
# Entrypoint script for Traefik v3.0 sidecar container
# Same logic as entrypoint-sidecar.sh; keep in sync for auth-forward and middlewares.

set -e

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

log "🚀 Starting Traefik v3.0 sidecar container..."

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

# When HOME_INDEX_URL is set, write ForwardAuth middlewares so lab routes require Firebase login.
if [ -n "${HOME_INDEX_URL:-}" ]; then
  AUTH_CHECK_URL="${HOME_INDEX_URL%/}/api/auth/check"
  log "Writing ForwardAuth middlewares to /shared/traefik/dynamic/auth-forward.yml (HOME_INDEX_URL=${HOME_INDEX_URL})"
  cat > /shared/traefik/dynamic/auth-forward.yml << EOF
# Generated at runtime - ForwardAuth to home-index for lab route protection
# High-priority public router for "/" so root is never protected (provider home-index has priority 1)
http:
  routers:
    home-index-root-public:
      rule: "Path(\`/\`)"
      priority: 1000
      service: home-index
      entryPoints:
        - web
      middlewares:
        - forwarded-headers@file
  middlewares:
    lab1-auth-check:
      forwardAuth:
        address: "${AUTH_CHECK_URL}"
        authResponseHeaders:
          - "X-User-Id"
          - "X-User-Email"
        authRequestHeaders:
          - "Authorization"
          - "Cookie"
          - "X-Forwarded-For"
          - "X-Forwarded-Host"
          - "X-Forwarded-Uri"
        trustForwardHeader: true
    lab2-auth-check:
      forwardAuth:
        address: "${AUTH_CHECK_URL}"
        authResponseHeaders:
          - "X-User-Id"
          - "X-User-Email"
        authRequestHeaders:
          - "Authorization"
          - "Cookie"
          - "X-Forwarded-For"
          - "X-Forwarded-Host"
          - "X-Forwarded-Uri"
        trustForwardHeader: true
    lab3-auth-check:
      forwardAuth:
        address: "${AUTH_CHECK_URL}"
        authResponseHeaders:
          - "X-User-Id"
          - "X-User-Email"
        authRequestHeaders:
          - "Authorization"
          - "Cookie"
          - "X-Forwarded-For"
          - "X-Forwarded-Host"
          - "X-Forwarded-Uri"
        trustForwardHeader: true
EOF
  log "✅ auth-forward.yml written (lab routes will require login)"
else
  log "HOME_INDEX_URL not set - lab auth middlewares not written (labs may be publicly accessible)"
fi

# Wait for routes.yml to be created by the provider sidecar
log "⏳ Waiting for provider sidecar to generate routes.yml..."
WAIT_TIMEOUT=60
WAIT_INTERVAL=2
WAITED=0
while [ ! -f /shared/traefik/dynamic/routes.yml ] || [ ! -s /shared/traefik/dynamic/routes.yml ]; do
  if [ $WAITED -ge $WAIT_TIMEOUT ]; then
    log "⚠️  Timeout waiting for routes.yml after ${WAIT_TIMEOUT}s"
    log "⚠️  Creating placeholder routes.yml - provider may update it later"
    cat > /shared/traefik/dynamic/routes.yml << 'PLACEHOLDER'
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

# Check config syntax (Traefik v3.0)
log "🔍 Checking config file syntax..."
if traefik version >/dev/null 2>&1; then
  if traefik --configfile=/etc/traefik/traefik.yml 2>&1 | grep -q "Configuration loaded"; then
    log "✅ Config file syntax is valid"
  else
    log "⚠️  Config validation check completed (may show warnings)"
  fi
fi

# Switch to traefik user for running Traefik (if we're root)
if [ "$(id -u)" = "0" ]; then
  log "🔄 Switching to traefik user..."
  exec su-exec traefik traefik --configfile=/etc/traefik/traefik.yml --entrypoints.web.address=0.0.0.0:8080 "$@"
else
  log "🚀 Starting Traefik..."
  log "   Config: /etc/traefik/traefik.yml"
  log "   Dynamic config: /shared/traefik/dynamic"
  log "   Entrypoint: web:8080"
  exec traefik --configfile=/etc/traefik/traefik.yml --entrypoints.web.address=0.0.0.0:8080 "$@"
fi
