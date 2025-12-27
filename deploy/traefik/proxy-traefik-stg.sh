#!/bin/bash
# Proxy Traefik staging service with support for both localhost and 127.0.0.1
# This script addresses the issue where localhost:8081 gives 404 but 127.0.0.1:8081 works

set -e

ENVIRONMENT="stg"
PROJECT_ID="labs-stg"
REGION="us-central1"
SERVICE_NAME="traefik-stg"
PORT="${1:-8081}"

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
if command -v socat &> /dev/null; then
  echo "   Using socat to bind to both localhost and 127.0.0.1..."
  # Start gcloud proxy in background, then use socat to forward
  gcloud run services proxy $SERVICE_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --port=$PORT &
  PROXY_PID=$!

  # Wait a moment for proxy to start
  sleep 2

  # Use socat to forward from IPv6 localhost to IPv4 127.0.0.1
  # This allows both localhost and 127.0.0.1 to work
  echo "   Setting up IPv6 to IPv4 forwarding..."
  socat TCP6-LISTEN:$PORT,bind=::1,reuseaddr,fork TCP4:127.0.0.1:$PORT &
  SOCAT_PID=$!

  echo "   ✅ Proxy running on both 127.0.0.1:$PORT and localhost:$PORT"
  echo "   Proxy PID: $PROXY_PID"
  echo "   Socat PID: $SOCAT_PID"
  echo ""

  # Wait for user interrupt
  trap "kill $PROXY_PID $SOCAT_PID 2>/dev/null; exit" INT TERM
  wait
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
