#!/bin/bash
# Proxy Traefik staging service with support for both localhost and 127.0.0.1
# This script addresses the issue where localhost gives 404 but 127.0.0.1 works

ENVIRONMENT="stg"
PROJECT_ID="labs-stg"
REGION="us-central1"
SERVICE_NAME="traefik-stg"

# Load STG_PROXY_PORT from .env.stg if available, otherwise default to 8082
# Port 8082 is used to avoid conflicts with local dev (8080) and dashboard (8081)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env.stg" ]; then
  # Source .env.stg and extract STG_PROXY_PORT
  # Use dotenvx if available, otherwise try to source directly (may fail with comments)
  if command -v dotenvx &> /dev/null && [ -f "$PROJECT_ROOT/.env.keys.stg" ]; then
    STG_PROXY_PORT=$(cd "$PROJECT_ROOT" && dotenvx run -f .env.stg -fk .env.keys.stg -- sh -c 'echo "$STG_PROXY_PORT"' 2>/dev/null | tail -n 1 | tr -d '\n\r' | xargs || echo "")
  else
    # Fallback: try to extract without dotenvx (may fail if encrypted)
    STG_PROXY_PORT=$(grep "^STG_PROXY_PORT=" "$PROJECT_ROOT/.env.stg" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | xargs || echo "")
  fi
fi

# Use command line argument, then STG_PROXY_PORT from .env.stg, then default to 8082
PORT="${1:-${STG_PROXY_PORT:-8082}}"

echo "🔗 Proxying Traefik staging service..."
echo "   Service: $SERVICE_NAME"
echo "   Project: $PROJECT_ID"
echo "   Port: $PORT"
echo ""

# Check if port is already in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "⚠️  Port $PORT is already in use"
  echo "   Kill the existing process or use a different port:"
  echo "   $0 <port>"
  exit 1
fi

# The gcloud run services proxy command binds to 127.0.0.1 by default
# On some systems, localhost resolves to IPv6 (::1) instead of IPv4 (127.0.0.1)
# This causes localhost:PORT to fail while 127.0.0.1:PORT works

echo "📝 Note: The proxy will bind to 127.0.0.1:$PORT"
echo "   - Access via: http://127.0.0.1:$PORT (always works)"
echo "   - Access via: http://localhost:$PORT (works if localhost resolves to 127.0.0.1)"
echo ""
echo "   If localhost:$PORT gives 404, check your /etc/hosts file:"
echo "   - Ensure: 127.0.0.1    localhost"
echo "   - Comment out: # ::1    localhost (if present)"
echo ""

# Start the proxy
echo "🚀 Starting proxy..."
echo "   Press Ctrl+C to stop"
echo ""

# Use socat or similar to bind to both addresses if available
# Otherwise, just use the standard gcloud command
PROXY_PID=""
SOCAT_PID=""

cleanup() {
  echo ""
  echo "   🛑 Shutting down proxy..."
  [ -n "$SOCAT_PID" ] && kill "$SOCAT_PID" 2>/dev/null && wait "$SOCAT_PID" 2>/dev/null
  [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null && wait "$PROXY_PID" 2>/dev/null
  # Kill any orphaned cloud-run-proxy on our port
  lsof -i :$PORT -sTCP:LISTEN -t 2>/dev/null | xargs kill 2>/dev/null
  echo "   ✅ Proxy stopped"
}

trap cleanup EXIT

if command -v socat &> /dev/null; then
  echo "   Using socat to bind to both localhost and 127.0.0.1..."
  # Start gcloud proxy in background, then use socat to forward
  gcloud run services proxy $SERVICE_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --port=$PORT &
  PROXY_PID=$!

  # Wait for proxy to start listening
  echo "   Waiting for proxy to start..."
  for i in $(seq 1 10); do
    if lsof -i :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! lsof -i :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "   ❌ Proxy failed to start"
    exit 1
  fi

  # Use socat to forward from IPv6 localhost to IPv4 127.0.0.1
  # This allows both localhost and 127.0.0.1 to work
  echo "   Setting up IPv6 to IPv4 forwarding..."
  socat TCP6-LISTEN:$PORT,bind=::1,reuseaddr,fork TCP4:127.0.0.1:$PORT &
  SOCAT_PID=$!

  echo "   ✅ Proxy running on both 127.0.0.1:$PORT and localhost:$PORT"
  echo "   Proxy PID: $PROXY_PID"
  echo "   Socat PID: $SOCAT_PID"
  echo ""

  # Wait for either process to exit; poll since macOS bash 3.2 lacks wait -n
  while kill -0 "$PROXY_PID" 2>/dev/null && kill -0 "$SOCAT_PID" 2>/dev/null; do
    sleep 1
  done
  echo "   ⚠️  A process exited unexpectedly"
  exit 1
else
  # Standard gcloud proxy (only binds to 127.0.0.1)
  echo "   ℹ️  socat not found - proxy will only work with 127.0.0.1:$PORT"
  echo "   Install socat for dual-binding: brew install socat (macOS) or apt-get install socat (Linux)"
  echo ""
  gcloud run services proxy $SERVICE_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --port=$PORT
fi
