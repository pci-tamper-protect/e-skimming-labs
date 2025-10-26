FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node for C2 server
RUN apk add --no-cache nodejs npm

# Copy website files to nginx html directory
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy C2 server
WORKDIR /app/c2-server
COPY package*.json ./
RUN npm install --production
COPY malicious-code/c2-server.js malicious-code/c2-server/dashboard.html ./

# Create default nginx config for banking site with C2 proxy
RUN echo 'server { \
    listen 8080; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index banking.html; \
    \
    location / { \
        try_files $uri $uri/ =404; \
    } \
    \
    location ~ ^/(stolen-data|api)/ { \
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
