#!/bin/sh
set -e

# HOST HACK: Nginx is configured to talk to "lab4-c2-server".
# In this monolith container, that should be localhost (127.0.0.1).
echo "127.0.0.1 lab4-c2-server" >> /etc/hosts

# Start nginx first (it needs to listen on PORT 8080 immediately for Cloud Run)
echo "Starting nginx on port 8080..."
nginx -g "daemon off;" &
NGINX_PID=$!

# Wait briefly for nginx
sleep 1

# Start C2 server in background (listens on port 3000 by default)
echo "Starting C2 server on port 3000..."
# Override PORT to 3000 to ensure internal C2 listens correctly
export PORT=3000
cd /app/c2-server && node server.js > /tmp/c2-server.log 2>&1 &
C2_PID=$!

echo "Services started - nginx (PID: $NGINX_PID), C2 server (PID: $C2_PID)"

# Wait for nginx (this keeps container running)
wait $NGINX_PID
