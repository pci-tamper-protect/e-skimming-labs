FROM nginx:1.25-alpine

# Install additional tools that might be needed
RUN apk add --no-cache \
    ca-certificates \
    curl \
    wget

# Copy website files to nginx html directory
COPY . /usr/share/nginx/html/

# Create default nginx config for banking site
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index banking.html; \
    \
    # Handle favicon requests without logging errors \
    location = /favicon.ico { \
        access_log off; \
        log_not_found off; \
        return 204; \
    } \
    \
    location / { \
        try_files $uri $uri/ =404; \
    } \
    \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ { \
        add_header Cache-Control "no-cache, no-store, must-revalidate"; \
        add_header Pragma "no-cache"; \
        add_header Expires "0"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
