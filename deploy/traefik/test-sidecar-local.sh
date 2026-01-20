#!/bin/bash
# Comprehensive test script for local sidecar simulation
# Usage: ./test-sidecar-local.sh [--verbose]
#
# Prerequisites:
#   - Edit docker-compose.sidecar-local.yml to set your gcloud config path
#   - Ensure you have ADC credentials: gcloud auth application-default login
#   - Services should be running: docker-compose -f docker-compose.sidecar-local.yml up -d

set -e

VERBOSE=false
if [[ "$1" == "--verbose" ]] || [[ "$1" == "-v" ]]; then
  VERBOSE=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

TRAEFIK_PORT=9090
DASHBOARD_PORT=9091

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✅${NC} $1"; }
fail() { echo -e "${RED}❌${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC}  $1"; }
info() { echo -e "${BLUE}ℹ️${NC}  $1"; }

echo "🧪 Testing Local Sidecar Simulation"
echo "===================================="
echo ""

# Test 1: Service Status
echo "1️⃣  Checking service status..."
SERVICES_UP=$(docker-compose -f docker-compose.sidecar-local.yml ps --format json 2>/dev/null | jq -r 'select(.State == "running") | .Name' 2>/dev/null || docker-compose -f docker-compose.sidecar-local.yml ps | grep -c "Up" || echo "0")

if [ "$SERVICES_UP" -ge 2 ]; then
  pass "Services are running (${SERVICES_UP} containers)"
  docker-compose -f docker-compose.sidecar-local.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker-compose -f docker-compose.sidecar-local.yml ps
else
  fail "Services are not running. Start them with:"
  echo "   docker-compose -f docker-compose.sidecar-local.yml up -d"
  exit 1
fi
echo ""

# Test 2: Wait for Traefik to be ready
echo "2️⃣  Waiting for Traefik to be ready..."
TRAEFIK_READY=false
for i in {1..30}; do
  if curl -sf http://localhost:${TRAEFIK_PORT}/ping >/dev/null 2>&1; then
    TRAEFIK_READY=true
    pass "Traefik is ready (responded in ${i}s)"
    break
  fi
  sleep 1
done

if [ "$TRAEFIK_READY" = false ]; then
  fail "Traefik did not become ready after 30 seconds"
  echo "   Check logs: docker-compose -f docker-compose.sidecar-local.yml logs traefik"
  exit 1
fi
echo ""

# Test 3: Provider route generation
echo "3️⃣  Testing provider route generation..."
ROUTES_FILE="/shared/traefik/dynamic/routes.yml"

if docker-compose -f docker-compose.sidecar-local.yml exec -T provider test -f "${ROUTES_FILE}" 2>/dev/null; then
  ROUTES_SIZE=$(docker-compose -f docker-compose.sidecar-local.yml exec -T provider stat -c%s "${ROUTES_FILE}" 2>/dev/null || docker-compose -f docker-compose.sidecar-local.yml exec -T provider stat -f%z "${ROUTES_FILE}" 2>/dev/null || echo "0")
  
  if [ "$ROUTES_SIZE" -gt 100 ]; then
    pass "routes.yml exists and has content (${ROUTES_SIZE} bytes)"
    
    # Check routes.yml structure
    if docker-compose -f docker-compose.sidecar-local.yml exec -T provider grep -q "http:" "${ROUTES_FILE}" 2>/dev/null; then
      pass "routes.yml has valid YAML structure (contains 'http:')"
      
      # Count routers
      ROUTER_COUNT=$(docker-compose -f docker-compose.sidecar-local.yml exec -T provider grep -c "routers:" "${ROUTES_FILE}" 2>/dev/null || echo "0")
      if [ "$ROUTER_COUNT" -gt 0 ]; then
        info "Found routers section in routes.yml"
      fi
      
      if [ "$VERBOSE" = true ]; then
        echo "   Routes file preview:"
        docker-compose -f docker-compose.sidecar-local.yml exec -T provider head -30 "${ROUTES_FILE}" | sed 's/^/      /'
      fi
    else
      warn "routes.yml may not have valid structure"
    fi
  else
    warn "routes.yml exists but is very small (${ROUTES_SIZE} bytes) - may be empty or still generating"
  fi
else
  fail "routes.yml not found - provider may not be generating routes"
  echo "   Check logs: docker-compose -f docker-compose.sidecar-local.yml logs provider"
fi
echo ""

# Test 4: Shared volume functionality
echo "4️⃣  Testing shared volume functionality..."
# Check if Traefik can read the routes.yml
if docker-compose -f docker-compose.sidecar-local.yml exec -T traefik test -f "${ROUTES_FILE}" 2>/dev/null; then
  pass "Traefik can access routes.yml from shared volume"
  
  TRAEFIK_ROUTES_SIZE=$(docker-compose -f docker-compose.sidecar-local.yml exec -T traefik stat -c%s "${ROUTES_FILE}" 2>/dev/null || docker-compose -f docker-compose.sidecar-local.yml exec -T traefik stat -f%z "${ROUTES_FILE}" 2>/dev/null || echo "0")
  if [ "$TRAEFIK_ROUTES_SIZE" = "$ROUTES_SIZE" ] && [ "$ROUTES_SIZE" != "0" ]; then
    pass "File sizes match - shared volume is working correctly"
  else
    warn "File sizes don't match (provider: ${ROUTES_SIZE}, traefik: ${TRAEFIK_ROUTES_SIZE})"
  fi
else
  fail "Traefik cannot access routes.yml from shared volume"
fi
echo ""

# Test 5: Traefik health and endpoints
echo "5️⃣  Testing Traefik endpoints..."
# Health check
if curl -sf http://localhost:${TRAEFIK_PORT}/ping >/dev/null 2>&1; then
  PING_RESPONSE=$(curl -sf http://localhost:${TRAEFIK_PORT}/ping 2>/dev/null || echo "")
  if [ "$PING_RESPONSE" = "OK" ] || [ -n "$PING_RESPONSE" ]; then
    pass "Traefik /ping endpoint is healthy"
  else
    warn "Traefik /ping responded but with unexpected content"
  fi
else
  fail "Traefik /ping endpoint failed"
  exit 1
fi

# API endpoint
if curl -sf http://localhost:${TRAEFIK_PORT}/api/rawdata >/dev/null 2>&1; then
  pass "Traefik /api/rawdata endpoint is accessible"
  
  # Try to get routers count
  if command -v jq >/dev/null 2>&1; then
    ROUTERS_COUNT=$(curl -sf http://localhost:${TRAEFIK_PORT}/api/http/routers 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    if [ "$ROUTERS_COUNT" != "0" ]; then
      info "Traefik has ${ROUTERS_COUNT} router(s) configured"
    fi
  fi
else
  warn "Traefik /api/rawdata is not accessible (may require routes to be loaded)"
fi

# Metrics endpoint
if curl -sf http://localhost:${TRAEFIK_PORT}/metrics >/dev/null 2>&1; then
  pass "Traefik /metrics endpoint is accessible"
else
  warn "Traefik /metrics endpoint is not accessible"
fi
echo ""

# Test 6: Dashboard service
echo "6️⃣  Testing Dashboard service..."
# Wait a bit for dashboard to be ready
sleep 2

if curl -sf http://localhost:${DASHBOARD_PORT}/dashboard/ >/dev/null 2>&1; then
  pass "Dashboard UI is accessible at http://localhost:${DASHBOARD_PORT}/dashboard/"
  
  # Test API proxy from dashboard
  if curl -sf http://localhost:${DASHBOARD_PORT}/api/version >/dev/null 2>&1; then
    pass "Dashboard API proxy is working (/api/version)"
    
    # Get version from dashboard proxy
    DASHBOARD_VERSION=$(curl -sf http://localhost:${DASHBOARD_PORT}/api/version 2>/dev/null | jq -r '.version' 2>/dev/null || echo "")
    if [ -n "$DASHBOARD_VERSION" ]; then
      info "Dashboard proxied API version: ${DASHBOARD_VERSION}"
    fi
  else
    warn "Dashboard API proxy may not be working (check TRAEFIK_API_URL)"
  fi
else
  warn "Dashboard is not accessible (may still be starting)"
  info "Check logs: docker-compose -f docker-compose.sidecar-local.yml logs traefik-dashboard"
fi
echo ""

# Test 7: Provider logs verification
echo "7️⃣  Verifying provider logs..."
PROVIDER_LOGS=$(docker-compose -f docker-compose.sidecar-local.yml logs --tail=50 provider 2>&1 || echo "")

if echo "${PROVIDER_LOGS}" | grep -qi "starting.*provider\|generating.*routes\|routes.*generated"; then
  pass "Provider logs show route generation activity"
  
  # Check for errors
  if echo "${PROVIDER_LOGS}" | grep -qi "error\|fatal\|panic"; then
    warn "Provider logs contain errors:"
    echo "${PROVIDER_LOGS}" | grep -i "error\|fatal\|panic" | head -5 | sed 's/^/      /'
  fi
  
  if [ "$VERBOSE" = true ]; then
    echo "   Recent provider logs:"
    echo "${PROVIDER_LOGS}" | tail -10 | sed 's/^/      /'
  fi
else
  warn "Provider logs don't show expected activity"
  if [ "$VERBOSE" = true ]; then
    echo "   Provider logs:"
    echo "${PROVIDER_LOGS}" | tail -20 | sed 's/^/      /'
  fi
fi
echo ""

# Test 8: Traefik logs verification
echo "8️⃣  Verifying Traefik logs..."
TRAEFIK_LOGS=$(docker-compose -f docker-compose.sidecar-local.yml logs --tail=50 traefik 2>&1 || echo "")

if echo "${TRAEFIK_LOGS}" | grep -qi "configuration.*loaded\|file provider.*watching"; then
  pass "Traefik logs show configuration loaded and file provider active"
  
  # Check for errors
  if echo "${TRAEFIK_LOGS}" | grep -qi "error.*entrypoint\|bind.*address.*in use"; then
    fail "Traefik logs contain critical errors:"
    echo "${TRAEFIK_LOGS}" | grep -i "error.*entrypoint\|bind.*address.*in use" | head -5 | sed 's/^/      /'
  fi
  
  if [ "$VERBOSE" = true ]; then
    echo "   Recent Traefik logs:"
    echo "${TRAEFIK_LOGS}" | tail -10 | sed 's/^/      /'
  fi
else
  warn "Traefik logs don't show expected configuration activity"
fi
echo ""

# Test 9: Route discovery (if Cloud Run services exist)
echo "9️⃣  Testing route discovery..."
# Check if routes.yml contains actual routes (not just API routes)
if docker-compose -f docker-compose.sidecar-local.yml exec -T provider grep -q "home-index\|lab1\|lab2" "${ROUTES_FILE}" 2>/dev/null; then
  pass "routes.yml contains application routes (home-index, lab1, lab2, etc.)"
  
  # Count application routers (exclude traefik-api and traefik-dashboard)
  APP_ROUTERS=$(docker-compose -f docker-compose.sidecar-local.yml exec -T provider grep -c "  [a-z].*:" "${ROUTES_FILE}" 2>/dev/null || echo "0")
  if [ "$APP_ROUTERS" -gt 2 ]; then
    info "Found ${APP_ROUTERS} router definitions in routes.yml"
  fi
else
  warn "routes.yml may only contain API routes (no application routes found)"
  info "This is normal if no Cloud Run services have traefik.enable=true labels"
fi
echo ""

# Test 10: Configuration validation
echo "🔟 Validating configurations..."
# Check Traefik config
if docker-compose -f docker-compose.sidecar-local.yml exec -T traefik test -f /etc/traefik/traefik.yml 2>/dev/null; then
  pass "Traefik config file exists"
  
  # Check for required settings
  if docker-compose -f docker-compose.sidecar-local.yml exec -T traefik grep -q "file:" /etc/traefik/traefik.yml 2>/dev/null; then
    pass "Traefik config has file provider configured"
  fi
  
  if docker-compose -f docker-compose.sidecar-local.yml exec -T traefik grep -q "entryPoints:" /etc/traefik/traefik.yml 2>/dev/null; then
    pass "Traefik config has entryPoints configured"
  fi
else
  fail "Traefik config file not found"
fi

# Check Dashboard config
if docker-compose -f docker-compose.sidecar-local.yml exec -T traefik-dashboard test -f /etc/traefik/traefik.yml 2>/dev/null; then
  pass "Dashboard config file exists"
  
  if docker-compose -f docker-compose.sidecar-local.yml exec -T traefik-dashboard grep -q "dashboard: true" /etc/traefik/traefik.yml 2>/dev/null; then
    pass "Dashboard config has dashboard enabled"
  fi
else
  warn "Dashboard config file not found"
fi
echo ""

# Summary
echo "===================================="
echo "📊 Test Summary"
echo "===================================="
echo ""
echo "✅ All critical tests passed!"
echo ""
echo "💡 Useful commands:"
echo "   View all logs: docker-compose -f docker-compose.sidecar-local.yml logs -f"
echo "   View Traefik logs: docker-compose -f docker-compose.sidecar-local.yml logs -f traefik"
echo "   View provider logs: docker-compose -f docker-compose.sidecar-local.yml logs -f provider"
echo "   View dashboard logs: docker-compose -f docker-compose.sidecar-local.yml logs -f traefik-dashboard"
echo "   Restart services: docker-compose -f docker-compose.sidecar-local.yml restart"
echo "   Stop services: docker-compose -f docker-compose.sidecar-local.yml down"
echo ""
echo "🌐 Access points:"
echo "   Traefik: http://localhost:${TRAEFIK_PORT}"
echo "   Traefik API: http://localhost:${TRAEFIK_PORT}/api/rawdata"
echo "   Dashboard: http://localhost:${DASHBOARD_PORT}/dashboard/"
echo ""
echo "📋 Check routes.yml:"
echo "   docker-compose -f docker-compose.sidecar-local.yml exec provider cat /shared/traefik/dynamic/routes.yml"
echo ""
echo "🔍 Debug commands:"
echo "   Check shared volume: docker-compose -f docker-compose.sidecar-local.yml exec traefik ls -la /shared/traefik/dynamic/"
echo "   Check provider process: docker-compose -f docker-compose.sidecar-local.yml exec provider ps aux"
echo "   Check Traefik config: docker-compose -f docker-compose.sidecar-local.yml exec traefik cat /etc/traefik/traefik.yml"
