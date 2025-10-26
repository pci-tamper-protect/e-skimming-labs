# Golden base image for Nginx services
# This image contains common nginx configuration and optimizations
# Used by: lab containers (01-basic-magecart, 02-dom-skimming, 03-extension-hijacking)

FROM nginx:1.25-alpine

# Install additional tools that might be needed
RUN apk add --no-cache \
    ca-certificates \
    curl \
    wget

# Create optimized nginx configuration
RUN cat > /etc/nginx/conf.d/default.conf << 'EOF'
server {
    listen 8080;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options "nosniff";
    }

    # Main location block
    location / {
        try_files $uri $uri/ =404;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create health check script
RUN echo '#!/bin/sh' > /usr/local/bin/health-check.sh && \
    echo 'wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1' >> /usr/local/bin/health-check.sh && \
    chmod +x /usr/local/bin/health-check.sh

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/health-check.sh

# Expose port 8080 (Cloud Run requirement)
EXPOSE 8080

# This base image is designed to be extended by individual labs
# Labs should copy their vulnerable-site/ directory to /usr/share/nginx/html/

