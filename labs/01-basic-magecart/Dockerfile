FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest AS nginx

# Copy website files to nginx html directory
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy custom nginx config
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/default.conf

# Configure nginx to listen on port 8080 (Cloud Run requirement)
RUN sed -i 's/listen 80;/listen 8080;/' /etc/nginx/conf.d/default.conf

# Expose port 8080
EXPOSE 8080

# Node.js stage for C2 server
FROM node:20-alpine AS c2

# Set working directory
WORKDIR /app

# Copy C2 server files
COPY malicious-code/c2-server/ .

# Install dependencies
RUN npm install --production

# Final stage: combine nginx and node
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

# Create init script
RUN cat > /init.sh << 'EOF'
#!/bin/sh
# Start C2 server in background
cd /app/c2-server && node server.js &
# Start nginx in foreground
nginx -g "daemon off;"
EOF
RUN chmod +x /init.sh

EXPOSE 8080

CMD ["/init.sh"]
