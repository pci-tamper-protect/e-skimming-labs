#!/bin/bash
# Restart proxy with current services - syncs hosts file and starts proxy

set -euo pipefail

ENVIRONMENT="${1:-stg}"
PROXY_PORT="${2:-8080}"

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

