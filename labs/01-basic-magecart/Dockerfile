FROM nginx:alpine

# Copy website files to nginx html directory
COPY vulnerable-site/ /usr/share/nginx/html/

# Copy custom nginx config
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
