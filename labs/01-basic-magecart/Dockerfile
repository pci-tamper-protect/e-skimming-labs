FROM nginx:alpine

# Copy website files to nginx html directory
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy custom nginx config
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/default.conf

# Configure nginx to listen on port 8080 (Cloud Run requirement)
RUN sed -i 's/listen 80;/listen 8080;/' /etc/nginx/conf.d/default.conf

# Expose port 8080
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
