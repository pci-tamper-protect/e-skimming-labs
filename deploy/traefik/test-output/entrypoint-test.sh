#!/bin/bash
# Injected mock get_identity_token for testing
get_identity_token() {
  local service_url=$1
  local token_var=""

  case "$service_url" in
    *home-index*) token_var="HOME_INDEX_TOKEN" ;;
    *home-seo*) token_var="SEO_TOKEN" ;;
    *analytics*) token_var="ANALYTICS_TOKEN" ;;
    *lab-01-basic-magecart*|*lab1*)
      if [[ "$service_url" == *c2* ]]; then
        token_var="LAB1_C2_TOKEN"
      else
        token_var="LAB1_TOKEN"
      fi
      ;;
    *lab-02-dom-skimming*|*lab2*)
      if [[ "$service_url" == *c2* ]]; then
        token_var="LAB2_C2_TOKEN"
      else
        token_var="LAB2_TOKEN"
      fi
      ;;
    *lab-03-extension*|*lab3*)
      if [[ "$service_url" == *extension* ]]; then
        token_var="LAB3_EXTENSION_TOKEN"
      else
        token_var="LAB3_TOKEN"
      fi
      ;;
  esac

  if [ -n "$token_var" ]; then
    eval "echo \$$token_var"
  else
    echo ""
  fi
}
# Entrypoint script for Traefik on Cloud Run
# Generates dynamic configuration from environment variables

set -e

echo "🚀 Starting Traefik for Cloud Run..."
echo "Environment: ${ENVIRONMENT:-local}"
echo "Domain: ${DOMAIN:-localhost}"

# Create dynamic config directory if it doesn't exist
mkdir -p /Users/kestenbroughton/projectos/e-skimming-labs/deploy/traefik/test-output/dynamic

# Function to get identity token from metadata server for a service URL
# get_identity_token() { # COMMENTED OUT FOR TESTING
#   local service_url=$1
#   if [ -z "$service_url" ] || [[ "$service_url" == http://localhost* ]]; then
#     # Local development or no URL - return empty
#     echo ""
#     return
#   fi
# 
#   # Extract the audience (service URL) for the token
#   local audience="$service_url"
# 
#   echo "  🔑 Fetching token for: ${service_url}" >&2
# 
#   # Get identity token from metadata server
#   # Metadata server is available at http://metadata.google.internal
#   # URL-encode the audience parameter
#   local encoded_audience=$(echo -n "$audience" | sed 's/:/%3A/g; s/\//%2F/g')
#   local metadata_url="http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${encoded_audience}"
# 
#   local token=$(curl -s -f -H "Metadata-Flavor: Google" "$metadata_url" 2>&1)
#   local curl_exit=$?
# 
#   if [ $curl_exit -ne 0 ] || [ -z "$token" ] || [[ "$token" == *"error"* ]] || [[ "$token" == *"Error"* ]]; then
#     echo "⚠️  Warning: Could not fetch identity token for ${service_url} (exit: $curl_exit)" >&2
#     if [ -n "$token" ]; then
#       echo "  Response: ${token:0:200}" >&2  # Truncate to first 200 chars
#     fi
#     echo ""
#   else
#     # Verify token looks valid (should start with eyJ for JWT)
#     if [[ "$token" =~ ^eyJ ]]; then
#       echo "  ✅ Token fetched successfully for ${service_url} (${#token} chars)" >&2
#       echo "$token"
#     else
#       echo "⚠️  Warning: Token response doesn't look valid for ${service_url}" >&2
#       echo "  Response preview: ${token:0:100}" >&2
#       echo ""
#     fi
#   fi
# } # END OF COMMENTED FUNCTION

# Fetch identity tokens for all backend services (only in Cloud Run, not local)
echo "🔍 Debug: ENVIRONMENT=${ENVIRONMENT}, HOME_INDEX_URL=${HOME_INDEX_URL}"
if [ "${ENVIRONMENT}" != "local" ] && [ -n "${HOME_INDEX_URL}" ] && [[ "${HOME_INDEX_URL}" != http://localhost* ]]; then
  echo "🔐 Fetching identity tokens for backend services..."

  HOME_INDEX_TOKEN=$(get_identity_token "${HOME_INDEX_URL}")
  SEO_TOKEN=$(get_identity_token "${SEO_URL}")
  ANALYTICS_TOKEN=$(get_identity_token "${ANALYTICS_URL}")
  LAB1_TOKEN=$(get_identity_token "${LAB1_URL}")
  LAB1_C2_TOKEN=$(get_identity_token "${LAB1_C2_URL}")
  LAB2_TOKEN=$(get_identity_token "${LAB2_URL}")
  LAB2_C2_TOKEN=$(get_identity_token "${LAB2_C2_URL}")
  LAB3_TOKEN=$(get_identity_token "${LAB3_URL}")
  LAB3_EXTENSION_TOKEN=$(get_identity_token "${LAB3_EXTENSION_URL}")

  # Log token status for debugging
  echo "Token fetch results:"
  [ -n "$HOME_INDEX_TOKEN" ] && echo "  ✅ HOME_INDEX_TOKEN: fetched (${#HOME_INDEX_TOKEN} chars)" || echo "  ❌ HOME_INDEX_TOKEN: empty"
  [ -n "$SEO_TOKEN" ] && echo "  ✅ SEO_TOKEN: fetched (${#SEO_TOKEN} chars)" || echo "  ❌ SEO_TOKEN: empty"
  [ -n "$ANALYTICS_TOKEN" ] && echo "  ✅ ANALYTICS_TOKEN: fetched (${#ANALYTICS_TOKEN} chars)" || echo "  ❌ ANALYTICS_TOKEN: empty"
  [ -n "$LAB1_TOKEN" ] && echo "  ✅ LAB1_TOKEN: fetched (${#LAB1_TOKEN} chars)" || echo "  ❌ LAB1_TOKEN: empty"
  [ -n "$LAB1_C2_TOKEN" ] && echo "  ✅ LAB1_C2_TOKEN: fetched (${#LAB1_C2_TOKEN} chars)" || echo "  ❌ LAB1_C2_TOKEN: empty"
  [ -n "$LAB2_TOKEN" ] && echo "  ✅ LAB2_TOKEN: fetched (${#LAB2_TOKEN} chars)" || echo "  ❌ LAB2_TOKEN: empty"
  [ -n "$LAB2_C2_TOKEN" ] && echo "  ✅ LAB2_C2_TOKEN: fetched (${#LAB2_C2_TOKEN} chars)" || echo "  ❌ LAB2_C2_TOKEN: empty"
  [ -n "$LAB3_TOKEN" ] && echo "  ✅ LAB3_TOKEN: fetched (${#LAB3_TOKEN} chars)" || echo "  ❌ LAB3_TOKEN: empty"
  [ -n "$LAB3_EXTENSION_TOKEN" ] && echo "  ✅ LAB3_EXTENSION_TOKEN: fetched (${#LAB3_EXTENSION_TOKEN} chars)" || echo "  ❌ LAB3_EXTENSION_TOKEN: empty"

  echo "✅ Identity tokens fetched"
else
  echo "ℹ️  Skipping identity token fetch (local development or URLs not set)"
  HOME_INDEX_TOKEN=""
  SEO_TOKEN=""
  ANALYTICS_TOKEN=""
  LAB1_TOKEN=""
  LAB1_C2_TOKEN=""
  LAB2_TOKEN=""
  LAB2_C2_TOKEN=""
  LAB3_TOKEN=""
  LAB3_EXTENSION_TOKEN=""
fi

# Remove static routes.yml if it exists (for local dev only, conflicts with generated config)
if [ -f "/Users/kestenbroughton/projectos/e-skimming-labs/deploy/traefik/test-output/dynamic/routes.yml" ]; then
  echo "⚠️  Removing static routes.yml (conflicts with generated cloudrun-services.yml)"
  rm /Users/kestenbroughton/projectos/e-skimming-labs/deploy/traefik/test-output/dynamic/routes.yml
fi

# Generate dynamic configuration from environment variables
cat > /Users/kestenbroughton/projectos/e-skimming-labs/deploy/traefik/test-output/dynamic/cloudrun-services.yml <<EOF
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
      middlewares:$(if [ -n "$HOME_INDEX_TOKEN" ]; then echo "
        - forwarded-headers
        - home-index-auth"; else echo "
        - forwarded-headers"; fi)
      entryPoints:
        - web

    # SEO service router
    seo-service:
      rule: "PathPrefix(\`/api/seo\`)"
      service: home-seo
      priority: 500
      middlewares:$(if [ -n "$SEO_TOKEN" ]; then echo "
        - forwarded-headers
        - home-seo-auth
        - strip-seo-prefix"; else echo "
        - forwarded-headers
        - strip-seo-prefix"; fi)
      entryPoints:
        - web

    # Analytics service router
    analytics-service:
      rule: "PathPrefix(\`/api/analytics\`)"
      service: labs-analytics
      priority: 500
      middlewares:$(if [ -n "$ANALYTICS_TOKEN" ]; then echo "
        - forwarded-headers
        - labs-analytics-auth
        - strip-analytics-prefix"; else echo "
        - forwarded-headers
        - strip-analytics-prefix"; fi)
      entryPoints:
        - web

    # Lab 1 - C2 server (higher priority)
    lab1-c2:
      rule: "PathPrefix(\`/lab1/c2\`)"
      service: lab1-c2-server
      priority: 300
      middlewares:$(if [ -n "$LAB1_C2_TOKEN" ]; then echo "
        - forwarded-headers
        - lab1-c2-auth
        - strip-lab1-c2-prefix"; else echo "
        - forwarded-headers
        - strip-lab1-c2-prefix"; fi)
      entryPoints:
        - web

    # Lab 1 - Main vulnerable site
    lab1-main:
      rule: "PathPrefix(\`/lab1\`)"
      service: lab1-vulnerable-site
      priority: 200
      middlewares:$(if [ -n "$LAB1_TOKEN" ]; then echo "
        - forwarded-headers
        - lab1-auth
        - strip-lab1-prefix"; else echo "
        - forwarded-headers
        - strip-lab1-prefix"; fi)
      entryPoints:
        - web

    # Lab 2 - C2 server (higher priority)
    lab2-c2:
      rule: "PathPrefix(\`/lab2/c2\`)"
      service: lab2-c2-server
      priority: 300
      middlewares:$(if [ -n "$LAB2_C2_TOKEN" ]; then echo "
        - forwarded-headers
        - lab2-c2-auth
        - strip-lab2-c2-prefix"; else echo "
        - forwarded-headers
        - strip-lab2-c2-prefix"; fi)
      entryPoints:
        - web

    # Lab 2 - Main vulnerable site
    lab2-main:
      rule: "PathPrefix(\`/lab2\`)"
      service: lab2-vulnerable-site
      priority: 200
      middlewares:$(if [ -n "$LAB2_TOKEN" ]; then echo "
        - forwarded-headers
        - lab2-auth
        - strip-lab2-prefix"; else echo "
        - forwarded-headers
        - strip-lab2-prefix"; fi)
      entryPoints:
        - web

    # Lab 3 - Extension server (higher priority)
    lab3-extension:
      rule: "PathPrefix(\`/lab3/extension\`)"
      service: lab3-extension-server
      priority: 300
      middlewares:$(if [ -n "$LAB3_EXTENSION_TOKEN" ]; then echo "
        - forwarded-headers
        - lab3-extension-auth
        - strip-lab3-extension-prefix"; else echo "
        - forwarded-headers
        - strip-lab3-extension-prefix"; fi)
      entryPoints:
        - web

    # Lab 3 - Main vulnerable site
    lab3-main:
      rule: "PathPrefix(\`/lab3\`)"
      service: lab3-vulnerable-site
      priority: 200
      middlewares:$(if [ -n "$LAB3_TOKEN" ]; then echo "
        - forwarded-headers
        - lab3-auth
        - strip-lab3-prefix"; else echo "
        - forwarded-headers
        - strip-lab3-prefix"; fi)
      entryPoints:
        - web

  middlewares:
    # Forwarded headers middleware
    forwarded-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"

    # Authentication middlewares (add identity tokens for Cloud Run services)
$(if [ -n "$HOME_INDEX_TOKEN" ]; then
  # Validate token format (should start with "eyJ" for JWT)
  if [[ "$HOME_INDEX_TOKEN" =~ ^eyJ ]]; then
    TOKEN_VALID="✅ Valid JWT format"
  else
    TOKEN_VALID="⚠️  Warning: Token doesn't look like a JWT (should start with 'eyJ')"
  fi

  # Escape the token for YAML (handle newlines, quotes, and special chars)
  # Remove any newlines and escape quotes
  TOKEN_ESC=$(echo -n "$HOME_INDEX_TOKEN" | tr -d '\n\r' | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
  TOKEN_PREVIEW="${HOME_INDEX_TOKEN:0:20}...${HOME_INDEX_TOKEN: -20}"
  echo "🔐 Generating home-index-auth middleware for ${HOME_INDEX_URL:-unknown}" >&2
  echo "   Token preview: ${TOKEN_PREVIEW}" >&2
  echo "   Token length: ${#HOME_INDEX_TOKEN} chars" >&2
  echo "   Escaped length: ${#TOKEN_ESC} chars" >&2
  echo "   ${TOKEN_VALID}" >&2

  # Use YAML literal block or quoted string to handle the token safely
  echo "    home-index-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)
$(if [ -n "$SEO_TOKEN" ]; then
  TOKEN_ESC=$(echo "$SEO_TOKEN" | sed 's/"/\\"/g')
  echo "    home-seo-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)
$(if [ -n "$ANALYTICS_TOKEN" ]; then
  TOKEN_ESC=$(echo "$ANALYTICS_TOKEN" | sed 's/"/\\"/g')
  echo "    labs-analytics-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)
$(if [ -n "$LAB1_TOKEN" ]; then
  TOKEN_ESC=$(echo "$LAB1_TOKEN" | sed 's/"/\\"/g')
  echo "    lab1-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)
$(if [ -n "$LAB1_C2_TOKEN" ]; then
  TOKEN_ESC=$(echo "$LAB1_C2_TOKEN" | sed 's/"/\\"/g')
  echo "    lab1-c2-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)
$(if [ -n "$LAB2_TOKEN" ]; then
  TOKEN_ESC=$(echo "$LAB2_TOKEN" | sed 's/"/\\"/g')
  echo "    lab2-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)
$(if [ -n "$LAB2_C2_TOKEN" ]; then
  TOKEN_ESC=$(echo "$LAB2_C2_TOKEN" | sed 's/"/\\"/g')
  echo "    lab2-c2-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)
$(if [ -n "$LAB3_TOKEN" ]; then
  TOKEN_ESC=$(echo "$LAB3_TOKEN" | sed 's/"/\\"/g')
  echo "    lab3-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)
$(if [ -n "$LAB3_EXTENSION_TOKEN" ]; then
  TOKEN_ESC=$(echo "$LAB3_EXTENSION_TOKEN" | sed 's/"/\\"/g')
  echo "    lab3-extension-auth:
      headers:
        customRequestHeaders:
          Authorization: \"Bearer ${TOKEN_ESC}\""
fi)

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

# Validate YAML syntax
if command -v yq &> /dev/null || command -v python3 &> /dev/null; then
  echo "🔍 Validating generated YAML configuration..."
  if python3 -c "import yaml; yaml.safe_load(open('/Users/kestenbroughton/projectos/e-skimming-labs/deploy/traefik/test-output/dynamic/cloudrun-services.yml'))" 2>/dev/null; then
    echo "  ✅ YAML syntax is valid"
  else
    echo "  ⚠️  YAML validation failed (non-critical, Traefik will validate on load)"
  fi
fi

# Show a snippet of the home-index-auth middleware if it exists
if [ -n "$HOME_INDEX_TOKEN" ]; then
  echo ""
  echo "📋 home-index-auth middleware snippet:"
  grep -A 5 "home-index-auth:" /Users/kestenbroughton/projectos/e-skimming-labs/deploy/traefik/test-output/dynamic/cloudrun-services.yml | head -6 || echo "  ⚠️  Could not read middleware from config file"
fi

echo ""
echo "Router Middleware Configuration:"
if [ -n "$HOME_INDEX_TOKEN" ]; then
  echo "  ✅ home-index router (PathPrefix /) → [forwarded-headers, home-index-auth]"
  echo "     This applies to: /, /mitre-attack, /threat-model, and all home-index paths"
else
  echo "  ⚪ home-index router (PathPrefix /) → [forwarded-headers] (no auth - token missing)"
fi
echo ""
echo "Auth Middlewares Created:"
[ -n "$HOME_INDEX_TOKEN" ] && echo "  ✅ home-index-auth" || echo "  ⚪ home-index-auth (no token)"
[ -n "$SEO_TOKEN" ] && echo "  ✅ home-seo-auth" || echo "  ⚪ home-seo-auth (no token)"
[ -n "$ANALYTICS_TOKEN" ] && echo "  ✅ labs-analytics-auth" || echo "  ⚪ labs-analytics-auth (no token)"
[ -n "$LAB1_TOKEN" ] && echo "  ✅ lab1-auth" || echo "  ⚪ lab1-auth (no token)"
[ -n "$LAB1_C2_TOKEN" ] && echo "  ✅ lab1-c2-auth" || echo "  ⚪ lab1-c2-auth (no token)"
[ -n "$LAB2_TOKEN" ] && echo "  ✅ lab2-auth" || echo "  ⚪ lab2-auth (no token)"
[ -n "$LAB2_C2_TOKEN" ] && echo "  ✅ lab2-c2-auth" || echo "  ⚪ lab2-c2-auth (no token)"
[ -n "$LAB3_TOKEN" ] && echo "  ✅ lab3-auth" || echo "  ⚪ lab3-auth (no token)"
[ -n "$LAB3_EXTENSION_TOKEN" ] && echo "  ✅ lab3-extension-auth" || echo "  ⚪ lab3-extension-auth (no token)"
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
echo "📝 Generated config file location: /Users/kestenbroughton/projectos/e-skimming-labs/deploy/traefik/test-output/dynamic/cloudrun-services.yml"
echo "   To inspect: cat /Users/kestenbroughton/projectos/e-skimming-labs/deploy/traefik/test-output/dynamic/cloudrun-services.yml | grep -A 10 'home-index-auth'"
echo ""

# Start Traefik with all arguments passed to this script
exec "$@"
