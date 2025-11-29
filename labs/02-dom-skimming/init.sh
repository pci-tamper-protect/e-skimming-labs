#!/bin/sh
# Start C2 server in background
cd /app/c2-server && node c2-server.js &
C2_PID=$!

# Wait for C2 server to be ready (check health endpoint)
echo "Waiting for C2 server to start..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if wget --no-verbose --tries=1 --spider --timeout=2 http://127.0.0.1:3000/health 2>/dev/null; then
    echo "C2 server is ready!"
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  sleep 1
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "WARNING: C2 server did not become ready in time, starting nginx anyway..."
fi

# Start nginx in foreground
nginx -g "daemon off;"

