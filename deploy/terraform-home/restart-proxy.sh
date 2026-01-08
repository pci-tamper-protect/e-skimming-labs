#!/bin/bash
# Restart proxy with current services - syncs hosts file and starts proxy

set -euo pipefail

ENVIRONMENT="${1:-stg}"

# Load STG_PROXY_PORT from .env.stg for staging, otherwise use provided port or default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [ "$ENVIRONMENT" = "stg" ] && [ -f "$PROJECT_ROOT/.env.stg" ]; then
  # Source .env.stg and extract STG_PROXY_PORT
  if command -v dotenvx &> /dev/null && [ -f "$PROJECT_ROOT/.env.keys.stg" ]; then
    STG_PROXY_PORT=$(cd "$PROJECT_ROOT" && dotenvx run -f .env.stg -fk .env.keys.stg -- sh -c 'echo "$STG_PROXY_PORT"' 2>/dev/null | tail -n 1 | tr -d '\n\r' | xargs || echo "")
  else
    # Fallback: try to extract without dotenvx (may fail if encrypted)
    STG_PROXY_PORT=$(grep "^STG_PROXY_PORT=" "$PROJECT_ROOT/.env.stg" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | xargs || echo "")
  fi
  # Use command line argument, then STG_PROXY_PORT from .env.stg, then default to 8082
  PROXY_PORT="${2:-${STG_PROXY_PORT:-8082}}"
else
  # For non-staging environments, use provided port or default to 8080
  PROXY_PORT="${2:-8080}"
fi

echo "🔄 Restarting proxy for $ENVIRONMENT environment"
echo ""

# Step 1: Sync hosts file
echo "📝 Step 1: Syncing /etc/hosts with current services..."
./sync-hosts-with-proxy.sh "$ENVIRONMENT" "$PROXY_PORT"
echo ""

# Step 2: Kill existing proxy if running
if lsof -i :$PROXY_PORT &>/dev/null; then
  echo "🛑 Stopping existing proxy on port $PROXY_PORT..."
  kill $(lsof -ti :$PROXY_PORT) 2>/dev/null || true
  sleep 1
  echo "✅ Stopped"
  echo ""
fi

# Step 3: Start new proxy
echo "🚀 Step 2: Starting proxy..."
echo ""
./start-multi-service-proxy.sh "$ENVIRONMENT" "$PROXY_PORT"

