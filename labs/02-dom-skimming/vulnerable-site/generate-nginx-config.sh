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
    listen 8080;
    server_name localhost;
    root /usr/share/nginx/html;
    index banking.html;

    # Environment-based routing
    # Production: serve lab versions with warnings (banking.html)
    # Staging: serve training versions without warnings (banking-train.html)
    
    location = /banking.html {
        # Rewrite to training version if staging
        if (\$host ~* "stg\.pcioasis\.com") {
            rewrite ^/banking.html$ /banking-train.html last;
        }
        try_files \$uri =404;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ ^/(stolen-data|api|stats|health) {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

echo "Generated nginx config for environment: $ENV_TYPE"

