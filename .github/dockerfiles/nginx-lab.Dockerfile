# Optimized Dockerfile for Nginx lab services using golden base image
# Usage: Set BASE_IMAGE build arg to point to golden base image

ARG BASE_IMAGE=nginx:1.25-alpine
FROM ${BASE_IMAGE}

# Copy website files to nginx html directory
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy custom nginx config if it exists, otherwise use default
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/custom.conf 2>/dev/null || true

# If custom config exists, use it; otherwise keep the golden base config
RUN if [ -f /usr/share/nginx/html/nginx.conf ]; then \
        cp /usr/share/nginx/html/nginx.conf /etc/nginx/conf.d/default.conf; \
    fi

# Configure nginx to listen on port 8080 (Cloud Run requirement)
RUN sed -i 's/listen 80;/listen 8080;/' /etc/nginx/conf.d/default.conf

# The golden base image already exposes port 8080 and has health check
# No additional configuration needed

