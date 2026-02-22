FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node for C2 server
RUN apk add --no-cache nodejs npm

# Copy C2 server dependencies first (for better caching)
WORKDIR /app/c2-server
COPY malicious-code/c2-server/package*.json ./
RUN npm install --production

# Copy C2 server source files
COPY malicious-code/c2-server/ ./

# Copy nginx config
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/default.conf

# Copy vulnerable site files (ALL files and subdirectories)
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Expose port (Cloud Run uses 8080)
EXPOSE 8080

CMD ["/init.sh"]