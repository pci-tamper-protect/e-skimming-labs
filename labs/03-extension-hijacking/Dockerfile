FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node for C2 server
RUN apk add --no-cache nodejs npm

# Copy C2 server dependencies first (for better caching)
WORKDIR /app/c2-server
COPY test-server/package*.json ./
RUN npm install --production

# Copy C2 server source files (this layer will be invalidated only when C2 code changes)
COPY test-server/extension-data-server.js test-server/dashboard.html ./

# Copy vulnerable site files last (this layer will be invalidated only when site files change)
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Expose port 8080
EXPOSE 8080

CMD ["/init.sh"]
