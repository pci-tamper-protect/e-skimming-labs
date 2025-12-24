#!/bin/bash
# Entrypoint script for Traefik on Cloud Run
# Generates dynamic configuration from environment variables

set -e

echo "🚀 Starting Traefik for Cloud Run..."
echo "Environment: ${ENVIRONMENT:-local}"
echo "Domain: ${DOMAIN:-localhost}"

# Create dynamic config directory if it doesn't exist
mkdir -p /etc/traefik/dynamic

# Generate dynamic configuration from environment variables
cat > /etc/traefik/dynamic/cloudrun-services.yml <<EOF
# Auto-generated Cloud Run service configuration
# Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Environment: ${ENVIRONMENT:-local}

http:
  routers:
    # Home page router
    home-index:
      rule: "PathPrefix(\`/\`)"
      service: home-index
      priority: 1
      entryPoints:
        - web

    # SEO service router
    seo-service:
      rule: "PathPrefix(\`/api/seo\`)"
      service: home-seo
      priority: 500
      middlewares:
        - strip-seo-prefix
      entryPoints:
        - web

    # Analytics service router
    analytics-service:
      rule: "PathPrefix(\`/api/analytics\`)"
      service: labs-analytics
      priority: 500
      middlewares:
        - strip-analytics-prefix
      entryPoints:
        - web

    # Lab 1 - C2 server (higher priority)
    lab1-c2:
      rule: "PathPrefix(\`/lab1/c2\`)"
      service: lab1-c2-server
      priority: 300
      middlewares:
        - strip-lab1-c2-prefix
      entryPoints:
        - web

    # Lab 1 - Main vulnerable site
    lab1-main:
      rule: "PathPrefix(\`/lab1\`)"
      service: lab1-vulnerable-site
      priority: 200
      middlewares:
        - strip-lab1-prefix
      entryPoints:
        - web

    # Lab 2 - C2 server (higher priority)
    lab2-c2:
      rule: "PathPrefix(\`/lab2/c2\`)"
      service: lab2-c2-server
      priority: 300
      middlewares:
        - strip-lab2-c2-prefix
      entryPoints:
        - web

    # Lab 2 - Main vulnerable site
    lab2-main:
      rule: "PathPrefix(\`/lab2\`)"
      service: lab2-vulnerable-site
      priority: 200
      middlewares:
        - strip-lab2-prefix
      entryPoints:
        - web

    # Lab 3 - Extension server (higher priority)
    lab3-extension:
      rule: "PathPrefix(\`/lab3/extension\`)"
      service: lab3-extension-server
      priority: 300
      middlewares:
        - strip-lab3-extension-prefix
      entryPoints:
        - web

    # Lab 3 - Main vulnerable site
    lab3-main:
      rule: "PathPrefix(\`/lab3\`)"
      service: lab3-vulnerable-site
      priority: 200
      middlewares:
        - strip-lab3-prefix
      entryPoints:
        - web

  middlewares:
    # Forwarded headers middleware
    forwarded-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"

    # Strip prefixes
    strip-seo-prefix:
      stripPrefix:
        prefixes:
          - "/api/seo"

    strip-analytics-prefix:
      stripPrefix:
        prefixes:
          - "/api/analytics"

    strip-lab1-prefix:
      stripPrefix:
        prefixes:
          - "/lab1"

    strip-lab1-c2-prefix:
      stripPrefix:
        prefixes:
          - "/lab1/c2"

    strip-lab2-prefix:
      stripPrefix:
        prefixes:
          - "/lab2"

    strip-lab2-c2-prefix:
      stripPrefix:
        prefixes:
          - "/lab2/c2"

    strip-lab3-prefix:
      stripPrefix:
        prefixes:
          - "/lab3"

    strip-lab3-extension-prefix:
      stripPrefix:
        prefixes:
          - "/lab3/extension"

  services:
    home-index:
      loadBalancer:
        servers:
          - url: "${HOME_INDEX_URL:-http://localhost:8080}"
        passHostHeader: false

    home-seo:
      loadBalancer:
        servers:
          - url: "${SEO_URL:-http://localhost:8080}"
        passHostHeader: false

    labs-analytics:
      loadBalancer:
        servers:
          - url: "${ANALYTICS_URL:-http://localhost:8080}"
        passHostHeader: false

    lab1-vulnerable-site:
      loadBalancer:
        servers:
          - url: "${LAB1_URL:-http://localhost:80}"
        passHostHeader: false

    lab1-c2-server:
      loadBalancer:
        servers:
          - url: "${LAB1_C2_URL:-http://localhost:3000}"
        passHostHeader: false

    lab2-vulnerable-site:
      loadBalancer:
        servers:
          - url: "${LAB2_URL:-http://localhost:80}"
        passHostHeader: false

    lab2-c2-server:
      loadBalancer:
        servers:
          - url: "${LAB2_C2_URL:-http://localhost:3000}"
        passHostHeader: false

    lab3-vulnerable-site:
      loadBalancer:
        servers:
          - url: "${LAB3_URL:-http://localhost:80}"
        passHostHeader: false

    lab3-extension-server:
      loadBalancer:
        servers:
          - url: "${LAB3_EXTENSION_URL:-http://localhost:3000}"
        passHostHeader: false
EOF

echo "✅ Generated Cloud Run service configuration"
echo ""
echo "Backend Services:"
echo "  HOME_INDEX_URL: ${HOME_INDEX_URL:-http://localhost:8080}"
echo "  SEO_URL: ${SEO_URL:-http://localhost:8080}"
echo "  ANALYTICS_URL: ${ANALYTICS_URL:-http://localhost:8080}"
echo "  LAB1_URL: ${LAB1_URL:-http://localhost:80}"
echo "  LAB1_C2_URL: ${LAB1_C2_URL:-http://localhost:3000}"
echo "  LAB2_URL: ${LAB2_URL:-http://localhost:80}"
echo "  LAB2_C2_URL: ${LAB2_C2_URL:-http://localhost:3000}"
echo "  LAB3_URL: ${LAB3_URL:-http://localhost:80}"
echo "  LAB3_EXTENSION_URL: ${LAB3_EXTENSION_URL:-http://localhost:3000}"
echo ""

# Start Traefik with all arguments passed to this script
exec "$@"
