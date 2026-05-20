FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/nginx-base:latest

COPY vulnerable-site/index.html /usr/share/nginx/html/index.html
COPY vulnerable-site/css/ /usr/share/nginx/html/css/
COPY vulnerable-site/js/ /usr/share/nginx/html/js/
COPY vulnerable-site/error-scripts/ /usr/share/nginx/html/error-scripts/
COPY vulnerable-site/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
