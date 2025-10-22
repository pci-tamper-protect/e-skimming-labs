FROM nginx:1.25-alpine

# Copy website files to nginx html directory
COPY vulnerable-site/ /usr/share/nginx/html/

# Create default nginx config for banking site
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
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Expose port 8080
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
