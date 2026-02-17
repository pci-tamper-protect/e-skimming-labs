FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

# Copy website files to nginx html directory
# Copy website files to nginx html directory (specific whitelist to prevent leaks)
COPY index.html css/ js/ original-favicon.ico /usr/share/nginx/html/

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 8080 (Cloud Run)
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
