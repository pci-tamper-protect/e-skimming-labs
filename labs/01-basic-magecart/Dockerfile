FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Copy nginx config
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/default.conf
RUN sed -i 's/listen 80;/listen 8080;/' /etc/nginx/conf.d/default.conf

# Copy vulnerable site files
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 8080

CMD ["/init.sh"]
