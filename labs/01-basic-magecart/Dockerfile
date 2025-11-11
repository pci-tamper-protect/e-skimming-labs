FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node
RUN apk add --no-cache nodejs npm

# Copy C2 server dependencies first (for better caching)
WORKDIR /app/c2-server
COPY malicious-code/c2-server/package*.json ./
RUN npm install --production

# Copy C2 server source files (this layer will be invalidated only when C2 code changes)
COPY malicious-code/c2-server/ ./

# Copy nginx config (this layer will be invalidated only when nginx config changes)
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/default.conf
RUN sed -i 's/listen 80;/listen 8080;/' /etc/nginx/conf.d/default.conf

# Copy vulnerable site files last (this layer will be invalidated only when site files change)
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 8080

CMD ["/init.sh"]
