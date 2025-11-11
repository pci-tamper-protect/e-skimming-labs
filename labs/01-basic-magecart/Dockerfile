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
EOF
RUN chmod +x /init.sh

EXPOSE 8080

CMD ["/init.sh"]
