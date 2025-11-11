FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node for C2 server
RUN apk add --no-cache nodejs npm

# Copy C2 server dependencies first (for better caching)
WORKDIR /app/c2-server
COPY package*.json ./
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
    location = /banking.html { \
        if ($host ~* "stg\.pcioasis\.com") { \
            rewrite ^/banking.html$ /banking-train.html last; \
        } \
        try_files $uri =404; \
    } \
    \
    location / { \
        try_files $uri $uri/ =404; \
    } \
    \
    location ~ ^/(stolen-data|api|stats|health) { \
        proxy_pass http://127.0.0.1:3000; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "upgrade"; \
        proxy_set_header Host $host; \
        proxy_cache_bypass $http_upgrade; \
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
# Start nginx in foreground
nginx -g "daemon off;"
EOF
RUN chmod +x /init.sh

# Expose port 8080
EXPOSE 8080

CMD ["/init.sh"]
