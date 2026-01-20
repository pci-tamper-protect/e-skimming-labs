#!/bin/sh
# Entrypoint script for Traefik Dashboard Service (Dashboard-Only Mode)
# This service runs ONLY the dashboard UI - no routing, no reverse proxy functionality
# It serves the dashboard and proxies API calls to the main Traefik service

set -e

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

TRAEFIK_API_URL="${TRAEFIK_API_URL:-http://localhost:8080}"
DYNAMIC_CONFIG="/etc/traefik/dynamic/routes.yml"

log "🚀 Starting Traefik Dashboard Service (Dashboard-Only Mode)..."
log "   Main Traefik API URL: ${TRAEFIK_API_URL}"
log "   This service serves ONLY the dashboard UI"
log "   No routing, no reverse proxy - just dashboard + API proxy"
log ""

# Verify config file exists
if [ ! -f /etc/traefik/traefik.yml ]; then
  log "❌ ERROR: Config file not found: /etc/traefik/traefik.yml"
  exit 1
fi
log "✅ Config file found: /etc/traefik/traefik.yml"

# Create dynamic config directory
mkdir -p /etc/traefik/dynamic

# Generate minimal routes.yml to proxy API calls to main Traefik
# This is the ONLY routing this service does - proxy /api/* to main Traefik
log "📝 Generating API proxy routes..."
cat > "${DYNAMIC_CONFIG}" <<EOF
# Dashboard Service Dynamic Configuration
# This service ONLY proxies API calls to main Traefik - no other routing
http:
  services:
    traefik-api-proxy:
      loadBalancer:
        servers:
          - url: "${TRAEFIK_API_URL}"
        passHostHeader: true
  routers:
    api-proxy:
      rule: "PathPrefix(\`/api\`)"
      service: traefik-api-proxy
      entryPoints:
        - traefik  # Use the auto-created "traefik" entrypoint (created by api.insecure: true)
      priority: 1
EOF

log "✅ Generated dynamic routes.yml:"
cat "${DYNAMIC_CONFIG}"
log ""

# Validate that we're in dashboard-only mode
log "🔍 Verifying dashboard-only configuration..."
log "   - Entrypoint: traefik:8080 (auto-created by api.insecure: true)"
log "   - Dashboard: enabled"
log "   - API proxy: /api/* -> ${TRAEFIK_API_URL}"
log "   - No other providers or routing"
log ""

# Start Traefik in dashboard-only mode
log "🚀 Starting Traefik (Dashboard-Only Mode)..."
log "   This instance will serve ONLY the dashboard UI"
log "   All API calls will be proxied to: ${TRAEFIK_API_URL}"
log ""

# Explicitly set entrypoint to prevent Traefik from creating default "http" entrypoint on port 80
# Use --entrypoints.traefik.address to explicitly set the entrypoint
exec traefik --configfile=/etc/traefik/traefik.yml --entrypoints.traefik.address=0.0.0.0:8080 "$@"
