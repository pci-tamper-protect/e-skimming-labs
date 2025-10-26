FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Copy website files to nginx html directory
COPY . /usr/share/nginx/html/

# Create default nginx config for banking site
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index banking.html; \
    \
    location / { \
        try_files $uri $uri/ =404; \
    } \
    \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
