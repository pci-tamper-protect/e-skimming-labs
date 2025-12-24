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

# Set PORT for Node.js server (use Cloud Run PORT or default to 3000)
export PORT=${PORT:-3000}

# Start C2 server in background
cd /app/c2-server && node extension-data-server.js &

# Wait for C2 server to be ready on the specified port
wait_for_port $PORT 30

# Start nginx in foreground
nginx -g "daemon off;"

