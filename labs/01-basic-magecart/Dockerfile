FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node
RUN apk add --no-cache nodejs npm

# Copy nginx files
COPY vulnerable-site/ /usr/share/nginx/html/
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/default.conf
RUN sed -i 's/listen 80;/listen 8080;/' /etc/nginx/conf.d/default.conf

# Copy C2 server
COPY malicious-code/c2-server/ /app/c2-server/
WORKDIR /app/c2-server
RUN npm install --production

# Create init script with proper error handling
RUN cat > /init.sh << 'EOF'
#!/bin/sh
set -e

# Start C2 server in background
echo "Starting C2 server..."
cd /app/c2-server && node server.js > /tmp/c2-server.log 2>&1 &
C2_PID=$!

# Wait a moment for C2 server to start
sleep 2

# Check if C2 server is still running
if ! ps -p $C2_PID > /dev/null; then
  echo "C2 server failed to start. Logs:"
  cat /tmp/c2-server.log
  exit 1
fi

echo "C2 server started (PID: $C2_PID)"
echo "Starting nginx..."

# Start nginx in foreground
exec nginx -g "daemon off;"
EOF
RUN chmod +x /init.sh

EXPOSE 8080

CMD ["/init.sh"]
