#!/bin/bash
# Entrypoint script for Traefik on Cloud Run
# Generates dynamic configuration from environment variables

# Don't use set -e initially - we want to see where failures occur
# set -e

# Write directly to Cloud Run logs via /proc/1/fd/1 (container's stdout)
# This ensures logs are captured even if stderr redirection doesn't work
LOG_FD=/proc/1/fd/1
if [ ! -w "$LOG_FD" ]; then
  # Fallback to stderr
  LOG_FD=/proc/1/fd/2
fi

# Function to log with timestamp
log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >&2
  # Also try writing directly to container stdout
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" > "$LOG_FD" 2>/dev/null || true
}

# Ensure all output goes to stderr so Cloud Run captures it
exec 1>&2

# Add error handler to log failures
trap 'log "ERROR: Script failed at line $LINENO"; exit 1' ERR

log "🚀 Starting Traefik for Cloud Run..."
log "Environment: ${ENVIRONMENT:-local}"
log "Domain: ${DOMAIN:-localhost}"
log "DEBUG: Script started"
log "DEBUG: Current user: $(whoami)"
log "DEBUG: Working directory: $(pwd)"
log "DEBUG: PATH: ${PATH}"

# Create dynamic config directory if it doesn't exist
log "DEBUG: Creating /etc/traefik/dynamic directory..."
mkdir -p /etc/traefik/dynamic || {
  log "ERROR: Failed to create /etc/traefik/dynamic"
  exit 1
}
log "DEBUG: Directory created successfully"

# Function to get identity token from metadata server for a service URL
get_identity_token() {
  local service_url=$1
  if [ -z "$service_url" ] || [[ "$service_url" == http://localhost* ]]; then
    # Local development or no URL - return empty
    echo ""
    return
  fi

  # Extract the audience (service URL) for the token
  # CRITICAL: The audience MUST exactly match the URL used in the HTTP request
  # This same service_url is used both for token generation and in the service definition
  local audience="$service_url"

  echo "  🔑 Fetching token for: ${service_url}" >&2
  echo "  📌 Token audience will be: ${audience} (must match request URL)" >&2

  # Get identity token from metadata server
  # Metadata server is available at http://metadata.google.internal
  # URL-encode the audience parameter
  local encoded_audience=$(echo -n "$audience" | sed 's/:/%3A/g; s/\//%2F/g')
  local metadata_url="http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${encoded_audience}"

  local token=$(curl -s -f -H "Metadata-Flavor: Google" "$metadata_url" 2>&1)
  local curl_exit=$?

  if [ $curl_exit -ne 0 ] || [ -z "$token" ] || [[ "$token" == *"error"* ]] || [[ "$token" == *"Error"* ]]; then
    echo "⚠️  Warning: Could not fetch identity token for ${service_url} (exit: $curl_exit)" >&2
    if [ -n "$token" ]; then
      echo "  Response: ${token:0:200}" >&2  # Truncate to first 200 chars
    fi
    echo ""
  else
    # Verify token looks valid (should start with eyJ for JWT)
    if [[ "$token" =~ ^eyJ ]]; then
      echo "  ✅ Token fetched successfully for ${service_url} (${#token} chars)" >&2
      echo "$token"
    else
      echo "⚠️  Warning: Token response doesn't look valid for ${service_url}" >&2
      echo "  Response preview: ${token:0:100}" >&2
      echo ""
    fi
  fi
}

# Fetch identity tokens for all backend services (only in Cloud Run, not local)
log "🔍 Debug: ENVIRONMENT=${ENVIRONMENT}, HOME_INDEX_URL=${HOME_INDEX_URL}"
if [ "${ENVIRONMENT}" != "local" ] && [ -n "${HOME_INDEX_URL}" ] && [[ "${HOME_INDEX_URL}" != http://localhost* ]]; then
  log "🔐 Fetching identity tokens for backend services..."

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

# Keep routes.yml for middleware definitions (middlewares are referenced with @file)
# Only remove it if we're generating from labels (which will create a new routes.yml)
if [ "${ENVIRONMENT}" != "local" ] && [ -f "/app/generate-routes-from-labels.sh" ]; then
  # Will be handled by label generation
  echo "ℹ️  routes.yml will be generated/merged by label-based generation"
else
  # For local dev, keep routes.yml for middleware definitions
  echo "ℹ️  Using routes.yml for middleware definitions (local development)"
fi

# Try to generate routes from Cloud Run service labels first (if script exists and we're in Cloud Run)
log "🔍 DEBUG: Checking conditions for label-based route generation..."
log "   ENVIRONMENT=${ENVIRONMENT:-<not set>}"
log "   ENVIRONMENT != local: $([ "${ENVIRONMENT}" != "local" ] && echo "true" || echo "false")"
log "   Script exists: $([ -f "/app/generate-routes-from-labels.sh" ] && echo "true" || echo "false")"
if [ -f "/app/generate-routes-from-labels.sh" ]; then
  log "   Script permissions: $(ls -l /app/generate-routes-from-labels.sh | awk '{print $1, $3, $4}')"
fi
log ""

if [ "${ENVIRONMENT}" != "local" ]; then
  # Prefer Go binary, fallback to bash script
  log "   DEBUG: Checking for Go binary at /app/generate-routes..."
  if [ -f "/app/generate-routes" ]; then
    log "   ✅ Go binary found at /app/generate-routes"
    log "🔍 Attempting to generate routes from Cloud Run service labels (Go SDK)..."
    log "   This will query Cloud Run services and extract Traefik labels"
    log "   to generate routers and services automatically."
    log "🚀 Calling generate-routes /etc/traefik/dynamic/routes.yml"
    log "   DEBUG: Full path: /app/generate-routes"
    log ""

    if /app/generate-routes /etc/traefik/dynamic/routes.yml 2>&1; then
      GENERATION_EXIT=$?
      log "   DEBUG: Generation script exited with code: ${GENERATION_EXIT}"
      # Check if routes.yml was created and has content
      if [ -f "/etc/traefik/dynamic/routes.yml" ] && [ -s "/etc/traefik/dynamic/routes.yml" ]; then
        log "✅ Routes generated successfully from Cloud Run labels (Go SDK)"
        log "   File size: $(stat -c%s /etc/traefik/dynamic/routes.yml 2>/dev/null || stat -f%z /etc/traefik/dynamic/routes.yml 2>/dev/null || echo "unknown") bytes"
      else
        log "⚠️  Routes file not created or empty, falling back to environment variables"
      fi
    else
      GENERATION_EXIT=$?
      log "⚠️  Route generation failed (exit: ${GENERATION_EXIT}), falling back to bash script or environment variables"
      # Fall through to bash script fallback
    fi
  else
    log "   ⚠️  Go binary not found at /app/generate-routes, will try bash script fallback"
  fi

  # Fallback to bash script if Go binary failed or doesn't exist
  if [ ! -f "/etc/traefik/dynamic/routes.yml" ] || [ ! -s "/etc/traefik/dynamic/routes.yml" ]; then
    if [ -f "/app/generate-routes-from-labels.sh" ]; then
      log "🔍 Attempting to generate routes from Cloud Run service labels (bash fallback)..."
      log "   This will query Cloud Run services and extract Traefik labels"
      log "   to generate routers and services automatically."
      log "🚀 Calling generate-routes-from-labels.sh /etc/traefik/dynamic/routes.yml"
      log "   DEBUG: Full path: /app/generate-routes-from-labels.sh"
      log ""

      if /app/generate-routes-from-labels.sh /etc/traefik/dynamic/routes.yml 2>&1; then
    GENERATION_EXIT=$?
    log "   DEBUG: Generation script exited with code: ${GENERATION_EXIT}"
    # Check if routes.yml was created and has content
    log "   DEBUG: Checking if routes.yml was created..."
    log "   DEBUG: File exists: $([ -f "/etc/traefik/dynamic/routes.yml" ] && echo "yes" || echo "no")"
    if [ -f "/etc/traefik/dynamic/routes.yml" ]; then
      log "   DEBUG: File size: $(wc -c < /etc/traefik/dynamic/routes.yml) bytes"
      log "   DEBUG: File non-empty: $([ -s "/etc/traefik/dynamic/routes.yml" ] && echo "yes" || echo "no")"
      log "   DEBUG: Has routers line: $(grep -q "^  routers:" /etc/traefik/dynamic/routes.yml && echo "yes" || echo "no")"
      log "   DEBUG: Has router entries: $(grep -q "^    [a-z]" /etc/traefik/dynamic/routes.yml && echo "yes" || echo "no")"
    fi
    log ""

    if [ -f "/etc/traefik/dynamic/routes.yml" ] && [ -s "/etc/traefik/dynamic/routes.yml" ]; then
      # Check if it has routers (not just empty file)
      if grep -q "^  routers:" /etc/traefik/dynamic/routes.yml && grep -q "^    [a-z]" /etc/traefik/dynamic/routes.yml; then
        log ""
        log "✅ Successfully generated routes from Cloud Run service labels"
        log "   Routers and services were auto-discovered from service labels"
        log "   Middlewares are defined in /etc/traefik/dynamic/routes.yml"
        log ""

        # Ensure Traefik API routes are present (required when insecure: false)
        # Based on: https://community.traefik.io/t/serving-traefiks-internal-dashboard-behind-traefik-itself/3457/7
        if ! grep -q "traefik-api:" /etc/traefik/dynamic/routes.yml; then
          log "⚠️  Traefik API routes not found in generated file, adding them..."
          # Insert API routes at the beginning of routers section (after "routers:")
          sed -i '/^  routers:/a\
    # Traefik API and Dashboard routers (high priority to match before application routes)\
    # Based on: https://community.traefik.io/t/serving-traefiks-internal-dashboard-behind-traefik-itself/3457/7\
    traefik-api:\
      rule: "PathPrefix(\`/api/http\`) || PathPrefix(\`/api/rawdata\`) || PathPrefix(\`/api/overview\`) || Path(\`/api/version\`)"\
      service: api@internal\
      priority: 1000\
      entryPoints:\
        - web\
    traefik-dashboard:\
      rule: "PathPrefix(\`/dashboard\`)"\
      service: api@internal\
      priority: 1000\
      entryPoints:\
        - web
' /etc/traefik/dynamic/routes.yml
          log "   ✅ Added Traefik API routes"
        else
          log "   ✅ Traefik API routes already present"
        fi

        # Merge middlewares from routes.yml (middlewares only file) into the generated file
        if [ -f "/etc/traefik/dynamic/routes.yml" ] && grep -q "^  middlewares:" /etc/traefik/dynamic/routes.yml; then
          echo "📋 Merging middlewares from routes.yml..."
          # Append middlewares section if not already present
          if ! grep -q "^  middlewares:" /etc/traefik/dynamic/routes.yml; then
            echo "" >> /etc/traefik/dynamic/routes.yml
            echo "  middlewares:" >> /etc/traefik/dynamic/routes.yml
          fi
          # Extract middlewares from the original routes.yml and append
          sed -n '/^  middlewares:/,$p' /etc/traefik/dynamic/routes.yml >> /etc/traefik/dynamic/routes.yml || true
        fi
        echo ""
        # Skip the environment variable-based generation
        exec "$@"
      else
        log "⚠️  Generated routes.yml is empty or has no routers, falling back to environment variables"
        log "   DEBUG: File contents preview:"
        head -20 /etc/traefik/dynamic/routes.yml 2>/dev/null | sed 's/^/      /' | while read line; do log "   $line"; done || log "      (could not read file)"
      fi
    else
      log "⚠️  Label-based generation did not create routes.yml, falling back to environment variables"
      log "   DEBUG: /etc/traefik/dynamic/routes.yml does not exist or is empty"
    fi
  else
    GENERATION_EXIT=$?
    log "⚠️  Label-based generation failed (exit code: ${GENERATION_EXIT}), falling back to environment variables"
    log "   DEBUG: Check logs above for generation script errors"
  fi
  fi
  fi
  log ""
else
  log "⚠️  DEBUG: Label-based generation skipped because:"
  if [ "${ENVIRONMENT}" = "local" ]; then
    log "   - ENVIRONMENT is 'local' (label-based generation only runs in Cloud Run)"
  fi
  if [ ! -f "/app/generate-routes-from-labels.sh" ]; then
    log "   - /app/generate-routes-from-labels.sh does not exist"
    log "   DEBUG: Checking /app directory contents:"
    ls -la /app/ 2>&1 | sed 's/^/      /' | while read line; do log "   $line"; done || log "      (could not list /app)"
  fi
  log ""
fi

# Fallback: Generate dynamic configuration from environment variables
# This is only used for local development or when label-based generation fails
# For Cloud Run, label-based generation should always work
if [ "${ENVIRONMENT}" = "local" ]; then
  echo "📋 Using environment variable-based configuration (local development)" >&2
  echo "" >&2
else
  echo "⚠️  WARNING: Falling back to environment variable-based configuration" >&2
  echo "   This should not happen in Cloud Run - label-based generation should work" >&2
  echo "   If you see this, check that services have Traefik labels" >&2
  echo "" >&2
fi

cat > /etc/traefik/dynamic/cloudrun-services.yml <<EOF
# Auto-generated Cloud Run service configuration
# Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Environment: ${ENVIRONMENT:-local}
# NOTE: For Cloud Run, routes should be generated from service labels, not env vars

http:
  routers:
    # Traefik API and Dashboard routers (high priority to match before application routes)
    # These routes expose Traefik's internal API and dashboard on port 8080
    # Based on: https://community.traefik.io/t/serving-traefiks-internal-dashboard-behind-traefik-itself/3457/7
    # When insecure: false, we must create explicit routes to api@internal
    # API: /api/http/*, /api/rawdata/*, /api/overview, etc.
    # Dashboard: /dashboard/
    traefik-api:
      rule: "PathPrefix(\`/api/http\`) || PathPrefix(\`/api/rawdata\`) || PathPrefix(\`/api/overview\`) || Path(\`/api/version\`)"
      service: api@internal
      priority: 1000  # High priority to match before application /api/* routes (seo=500, analytics=500)
      entryPoints:
        - web
    traefik-dashboard:
      rule: "PathPrefix(\`/dashboard\`)"
      service: api@internal
      priority: 1000  # High priority
      entryPoints:
        - web

    # Home page router
    home-index:
      rule: "PathPrefix(\`/\`)"
      service: home-index
      priority: 1
      middlewares:$(if [ -n "$HOME_INDEX_TOKEN" ]; then echo "
        - forwarded-headers
        - home-index-auth
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - retry-cold-start@file"; fi)
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
        - strip-seo-prefix
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - strip-seo-prefix
        - retry-cold-start@file"; fi)
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
        - strip-analytics-prefix
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - strip-analytics-prefix
        - retry-cold-start@file"; fi)
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
        - strip-lab1-c2-prefix
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - strip-lab1-c2-prefix
        - retry-cold-start@file"; fi)
      entryPoints:
        - web

    # Lab 1 - Main vulnerable site
    lab1-main:
      rule: "PathPrefix(\`/lab1\`)"
      service: lab1-vulnerable-site
      priority: 200
      middlewares:$(if [ -n "$LAB1_TOKEN" ]; then echo "
        - forwarded-headers
        - lab1-auth-check
        - lab1-auth
        - strip-lab1-prefix
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - lab1-auth-check
        - strip-lab1-prefix
        - retry-cold-start@file"; fi)
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
        - strip-lab2-c2-prefix
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - strip-lab2-c2-prefix
        - retry-cold-start@file"; fi)
      entryPoints:
        - web

    # Lab 2 - Main vulnerable site
    lab2-main:
      rule: "PathPrefix(\`/lab2\`)"
      service: lab2-vulnerable-site
      priority: 200
      middlewares:$(if [ -n "$LAB2_TOKEN" ]; then echo "
        - forwarded-headers
        - lab2-auth-check
        - lab2-auth
        - strip-lab2-prefix
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - lab2-auth-check
        - strip-lab2-prefix
        - retry-cold-start@file"; fi)
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
        - strip-lab3-extension-prefix
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - strip-lab3-extension-prefix
        - retry-cold-start@file"; fi)
      entryPoints:
        - web

    # Lab 3 - Main vulnerable site
    lab3-main:
      rule: "PathPrefix(\`/lab3\`)"
      service: lab3-vulnerable-site
      priority: 200
      middlewares:$(if [ -n "$LAB3_TOKEN" ]; then echo "
        - forwarded-headers
        - lab3-auth-check
        - lab3-auth
        - strip-lab3-prefix
        - retry-cold-start@file"; else echo "
        - forwarded-headers
        - lab3-auth-check
        - strip-lab3-prefix
        - retry-cold-start@file"; fi)
      entryPoints:
        - web

  middlewares:
    # Forwarded headers middleware
    forwarded-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        # Forward X-Forwarded-For so backend can detect proxy access
        # This allows home-index to use relative URLs when accessed via proxy
        # The gcloud proxy sets X-Forwarded-For with 127.0.0.1
        # Note: Traefik v3.0 automatically forwards X-Forwarded-For and X-Forwarded-Host headers

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

    # Retry middleware for handling cold starts
    retry-cold-start:
      retry:
        attempts: 3

    # User authentication check middlewares (forwardAuth)
    # Note: X-Forwarded-For and X-Forwarded-Host are forwarded so home-index can detect proxy access
    lab1-auth-check:
      forwardAuth:
        address: "${HOME_INDEX_URL:-http://home-index:8080}/api/auth/check"
        authResponseHeaders:
          - "X-User-Id"
          - "X-User-Email"
        authRequestHeaders:
          - "Authorization"
          - "Cookie"
          - "X-Forwarded-For"
          - "X-Forwarded-Host"
        trustForwardHeader: true

    lab2-auth-check:
      forwardAuth:
        address: "${HOME_INDEX_URL:-http://home-index:8080}/api/auth/check"
        authResponseHeaders:
          - "X-User-Id"
          - "X-User-Email"
        authRequestHeaders:
          - "Authorization"
          - "Cookie"
          - "X-Forwarded-For"
          - "X-Forwarded-Host"
        trustForwardHeader: true

    lab3-auth-check:
      forwardAuth:
        address: "${HOME_INDEX_URL:-http://home-index:8080}/api/auth/check"
        authResponseHeaders:
          - "X-User-Id"
          - "X-User-Email"
        authRequestHeaders:
          - "Authorization"
          - "Cookie"
          - "X-Forwarded-For"
          - "X-Forwarded-Host"
        trustForwardHeader: true

  services:
    home-index:
      loadBalancer:
        servers:
          - url: "${HOME_INDEX_URL:-http://home-index:8080}"
        passHostHeader: false

    home-seo:
      loadBalancer:
        servers:
          - url: "${SEO_URL:-http://home-seo:8080}"
        passHostHeader: false

    labs-analytics:
      loadBalancer:
        servers:
          - url: "${ANALYTICS_URL:-http://labs-analytics:8080}"
        passHostHeader: false

    lab1-vulnerable-site:
      loadBalancer:
        servers:
          - url: "${LAB1_URL:-http://lab1-vulnerable-site:8080}"
        passHostHeader: false

    lab1-c2-server:
      loadBalancer:
        servers:
          - url: "${LAB1_C2_URL:-http://lab1-c2-server:8080}"
        passHostHeader: false

    lab2-vulnerable-site:
      loadBalancer:
        servers:
          - url: "${LAB2_URL:-http://lab2-vulnerable-site:8080}"
        passHostHeader: false

    lab2-c2-server:
      loadBalancer:
        servers:
          - url: "${LAB2_C2_URL:-http://lab2-c2-server:8080}"
        passHostHeader: false

    lab3-vulnerable-site:
      loadBalancer:
        servers:
          - url: "${LAB3_URL:-http://lab3-vulnerable-site:8080}"
        passHostHeader: false

    lab3-extension-server:
      loadBalancer:
        servers:
          - url: "${LAB3_EXTENSION_URL:-http://lab3-extension-server:8080}"
        passHostHeader: false
EOF

echo "✅ Generated Cloud Run service configuration" >&2
echo "" >&2

# Validate YAML syntax
if command -v yq &> /dev/null || command -v python3 &> /dev/null; then
  echo "🔍 Validating generated YAML configuration..." >&2
  if python3 -c "import yaml; yaml.safe_load(open('/etc/traefik/dynamic/cloudrun-services.yml'))" 2>/dev/null; then
    echo "  ✅ YAML syntax is valid" >&2
  else
    echo "  ⚠️  YAML validation failed (non-critical, Traefik will validate on load)" >&2
  fi
fi

# Show a snippet of the home-index-auth middleware if it exists
if [ -n "$HOME_INDEX_TOKEN" ]; then
  echo "" >&2
  echo "📋 home-index-auth middleware snippet:" >&2
  grep -A 5 "home-index-auth:" /etc/traefik/dynamic/cloudrun-services.yml | head -6 >&2 || echo "  ⚠️  Could not read middleware from config file" >&2
fi

echo "" >&2
echo "Router Middleware Configuration:" >&2
if [ -n "$HOME_INDEX_TOKEN" ]; then
  echo "  ✅ home-index router (PathPrefix /) → [forwarded-headers, home-index-auth]" >&2
  echo "     This applies to: /, /mitre-attack, /threat-model, and all home-index paths" >&2
else
  echo "  ⚪ home-index router (PathPrefix /) → [forwarded-headers] (no auth - token missing)" >&2
fi
echo "" >&2
echo "Auth Middlewares Created:" >&2
[ -n "$HOME_INDEX_TOKEN" ] && echo "  ✅ home-index-auth" >&2 || echo "  ⚪ home-index-auth (no token)" >&2
[ -n "$SEO_TOKEN" ] && echo "  ✅ home-seo-auth" >&2 || echo "  ⚪ home-seo-auth (no token)" >&2
[ -n "$ANALYTICS_TOKEN" ] && echo "  ✅ labs-analytics-auth" >&2 || echo "  ⚪ labs-analytics-auth (no token)" >&2
[ -n "$LAB1_TOKEN" ] && echo "  ✅ lab1-auth" >&2 || echo "  ⚪ lab1-auth (no token)" >&2
[ -n "$LAB1_C2_TOKEN" ] && echo "  ✅ lab1-c2-auth" >&2 || echo "  ⚪ lab1-c2-auth (no token)" >&2
[ -n "$LAB2_TOKEN" ] && echo "  ✅ lab2-auth" >&2 || echo "  ⚪ lab2-auth (no token)" >&2
[ -n "$LAB2_C2_TOKEN" ] && echo "  ✅ lab2-c2-auth" >&2 || echo "  ⚪ lab2-c2-auth (no token)" >&2
[ -n "$LAB3_TOKEN" ] && echo "  ✅ lab3-auth" >&2 || echo "  ⚪ lab3-auth (no token)" >&2
[ -n "$LAB3_EXTENSION_TOKEN" ] && echo "  ✅ lab3-extension-auth" >&2 || echo "  ⚪ lab3-extension-auth (no token)" >&2
echo "" >&2
echo "Backend Services:" >&2
echo "  HOME_INDEX_URL: ${HOME_INDEX_URL:-http://home-index:8080 (default for local)}" >&2
echo "  SEO_URL: ${SEO_URL:-http://home-seo:8080 (default for local)}" >&2
echo "  ANALYTICS_URL: ${ANALYTICS_URL:-http://labs-analytics:8080 (default for local)}" >&2
echo "  LAB1_URL: ${LAB1_URL:-http://lab1-vulnerable-site:8080 (default for local)}" >&2
echo "  LAB1_C2_URL: ${LAB1_C2_URL:-http://lab1-c2-server:8080 (default for local)}" >&2
echo "  LAB2_URL: ${LAB2_URL:-http://lab2-vulnerable-site:8080 (default for local)}" >&2
echo "  LAB2_C2_URL: ${LAB2_C2_URL:-http://lab2-c2-server:8080 (default for local)}" >&2
echo "  LAB3_URL: ${LAB3_URL:-http://lab3-vulnerable-site:8080 (default for local)}" >&2
echo "  LAB3_EXTENSION_URL: ${LAB3_EXTENSION_URL:-http://lab3-extension-server:8080 (default for local)}" >&2
echo "" >&2
echo "📝 Generated config file location: /etc/traefik/dynamic/cloudrun-services.yml" >&2
echo "   To inspect: cat /etc/traefik/dynamic/cloudrun-services.yml | grep -A 10 'home-index-auth'" >&2
echo "" >&2
echo "🔍 ForwardAuth Middlewares in Generated Config:" >&2
grep -A 10 "auth-check:" /etc/traefik/dynamic/cloudrun-services.yml >&2 || echo "  ⚠️  No ForwardAuth middlewares found!" >&2
echo "" >&2

# Start periodic route refresh in background
# First minute: refresh every 5 seconds (catches services deployed right after Traefik starts)
# After first minute: refresh every 5 minutes (normal operation)
# This keeps routes up-to-date when new services are deployed
if [ "${ENVIRONMENT}" != "local" ] && [ -f "/app/generate-routes-from-labels.sh" ] && [ -f "/app/refresh-routes.sh" ]; then
  echo "🔄 Starting periodic route refresh..." >&2
  echo "   First minute: every 5 seconds (fast discovery)" >&2
  echo "   After first minute: every 5 minutes (normal operation)" >&2
  (
    START_TIME=$(date +%s)
    FAST_REFRESH_END=$((START_TIME + 60))  # First 60 seconds

    while true; do
      CURRENT_TIME=$(date +%s)

      if [ $CURRENT_TIME -lt $FAST_REFRESH_END ]; then
        # Fast refresh: every 5 seconds for first minute
        sleep 5
      else
        # Normal refresh: every 5 minutes after first minute
        sleep 300
      fi

      /app/refresh-routes.sh /etc/traefik/dynamic/routes.yml /tmp/traefik-refresh.log 2>&1 || true
    done
  ) &
  REFRESH_PID=$!
  echo "   Background refresh PID: ${REFRESH_PID}" >&2
  echo "" >&2
fi

# Start Traefik with all arguments passed to this script
log "DEBUG: About to exec Traefik with args: $@"
log "DEBUG: Current time: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
log "DEBUG: Entrypoint script completed, starting Traefik..."
exec "$@"
