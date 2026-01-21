#!/bin/sh

# Function to wait for a service to be ready
wait_for_port() {
    local port=$1
    local timeout=${2:-30}
    local count=0
    
    echo "Waiting for service on port $port..."
    while ! nc -z localhost $port; do
        sleep 1
        count=$((count + 1))
        if [ $count -gt $timeout ]; then
            echo "Timeout waiting for service on port $port"
            exit 1
        fi
    done
    echo "Service on port $port is ready!"
}

# C2 server ALWAYS runs on port 3000 when running with nginx
# nginx listens on 8080 (Cloud Run's PORT) and proxies /extension requests to C2
# DO NOT use Cloud Run's PORT env var for C2 - that's for nginx
C2_PORT=3000

# Start C2 server in background on port 3000
cd /app/c2-server && PORT=$C2_PORT node extension-data-server.js &

# Wait for C2 server to be ready
wait_for_port $C2_PORT 30

# Start nginx in foreground (listens on 8080 - Cloud Run's PORT)
nginx -g "daemon off;"

