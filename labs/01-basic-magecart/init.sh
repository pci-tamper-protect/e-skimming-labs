#!/bin/sh
set -e

# Start nginx first (it needs to listen on PORT immediately for Cloud Run health check)
echo "Starting nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!

# Wait briefly for nginx to bind to port
sleep 1

# Start C2 server in background
echo "Starting C2 server..."
cd /app/c2-server && node server.js > /tmp/c2-server.log 2>&1 &
C2_PID=$!

echo "Services started - nginx (PID: $NGINX_PID), C2 server (PID: $C2_PID)"

# Wait for nginx (this keeps container running)
wait $NGINX_PID

