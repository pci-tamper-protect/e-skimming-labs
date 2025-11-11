FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node for C2 server
RUN apk add --no-cache nodejs npm

# Copy C2 server dependencies first (for better caching)
WORKDIR /app/c2-server
# Copy package.json (package-lock.json is optional and will be generated if missing)
COPY package.json ./
RUN npm install --production

# Copy C2 server source files (this layer will be invalidated only when C2 code changes)
COPY malicious-code/c2-server.js malicious-code/c2-server/dashboard.html ./

# Copy vulnerable site files last (this layer will be invalidated only when site files change)
COPY vulnerable-site/ /usr/share/nginx/html/

# Create default nginx config for banking site with C2 proxy
RUN echo 'server { \
    listen 8080; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index banking.html; \
    \
    # Environment-based routing \
    # Production (labs.pcioasis.com): serve lab versions with warnings \
    # Staging (labs.stg.pcioasis.com): serve training versions without warnings \
    # Handle both root paths (/) and path-prefixed routes (/lab-02-dom-skimming/) \
    # C2 server proxy routes (must come before static file routes) \
    location ~ ^/(stolen-data|api|stats|health|collect) { \
        proxy_pass http://127.0.0.1:3000; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "upgrade"; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
        proxy_cache_bypass $http_upgrade; \
        proxy_connect_timeout 10s; \
        proxy_send_timeout 30s; \
        proxy_read_timeout 30s; \
        proxy_buffering off; \
    } \
    \
    # Handle path-prefixed routes (production Cloud Run) \
    location ~ ^/lab-02-dom-skimming(/.*)?$ { \
        set $path $1; \
        if ($path = "") { set $path /; } \
        if ($host ~* "stg\.pcioasis\.com") { \
            rewrite ^/lab-02-dom-skimming(/.*)?$ /banking-train.html last; \
        } \
        try_files $path /banking.html =404; \
    } \
    \
    # Handle root paths (localhost and production root) \
    location = /banking.html { \
        if ($host ~* "stg\.pcioasis\.com") { \
            rewrite ^/banking.html$ /banking-train.html last; \
        } \
        try_files $uri =404; \
    } \
    \
    location = / { \
        if ($host ~* "stg\.pcioasis\.com") { \
            rewrite ^/$ /banking-train.html last; \
        } \
        try_files $uri $uri/ /banking.html =404; \
    } \
    \
    location / { \
        try_files $uri $uri/ /banking.html =404; \
    } \
    \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Create init script
RUN cat > /init.sh << 'EOF'
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
EOF
RUN chmod +x /init.sh

# Expose port 8080
EXPOSE 8080

CMD ["/init.sh"]
