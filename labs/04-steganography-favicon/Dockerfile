FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node for C2 server
RUN apk add --no-cache nodejs npm

# C2 server
WORKDIR /app/c2-server
COPY malicious-code/c2-server/package*.json ./
RUN npm install --production
COPY malicious-code/c2-server/server.js malicious-code/c2-server/dashboard.html ./
RUN mkdir -p stolen-data

# Vulnerable site
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy nginx config (with C2 proxy block)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Expose port 8080 (Cloud Run standard)
EXPOSE 8080

CMD ["/init.sh"]
