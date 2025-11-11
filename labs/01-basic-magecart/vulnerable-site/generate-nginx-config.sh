#!/bin/sh
# Generate nginx config with environment-based routing

# Determine environment from hostname or APP_ENV
if [ -n "$APP_ENV" ]; then
  ENV_TYPE="$APP_ENV"
elif echo "$HOSTNAME" | grep -q "stg\.pcioasis\.com"; then
  ENV_TYPE="staging"
else
  ENV_TYPE="production"
fi

# Generate nginx config
cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Disable caching for lab purposes
    add_header Cache-Control "no-store, no-cache, must-revalidate";

    # CORS headers (intentionally permissive for lab)
    add_header Access-Control-Allow-Origin "*";
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
    add_header Access-Control-Allow-Headers "Content-Type";

    # Environment-based routing
    # Production: serve lab versions with warnings (checkout.html)
    # Staging: serve training versions without warnings (checkout-train.html)
    
    location = /checkout.html {
        # Rewrite to training version if staging
        if (\$host ~* "stg\.pcioasis\.com") {
            rewrite ^/checkout.html$ /checkout-train.html last;
        }
        try_files \$uri =404;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Serve static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires -1;
        add_header Cache-Control "no-store";
    }

    # Proxy C2 server requests
    location ~ ^/(stolen|collect|api|stats|health|dashboard) {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    # Enable gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

echo "Generated nginx config for environment: $ENV_TYPE"

