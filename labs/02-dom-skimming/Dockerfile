FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Install node for C2 server
RUN apk add --no-cache nodejs npm

# C2 server (sibling to vulnerable-site)
WORKDIR /app/c2-server
COPY c2-server/package*.json ./
RUN npm install --production
COPY c2-server/server.js c2-server/dashboard.html ./
RUN mkdir -p stolen-data analysis

# Vulnerable site (includes malicious-code/ with dom-monitor, form-overlay, shadow-skimmer)
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Expose port 8080
EXPOSE 8080

CMD ["/init.sh"]
