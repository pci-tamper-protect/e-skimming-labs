FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Vulnerable site (includes malicious-code/ with dom-monitor, form-overlay, shadow-skimmer)
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 8080

CMD ["/init.sh"]
