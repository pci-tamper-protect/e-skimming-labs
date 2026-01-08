#!/bin/bash
# Test entrypoint.sh locally by mocking the metadata server
# Usage: ./test-entrypoint.sh [local|stg|prd]
# Default: local

set -e

# Parse environment argument
TEST_ENV="${1:-local}"

if [[ ! "$TEST_ENV" =~ ^(local|stg|prd)$ ]]; then
  echo "❌ ERROR: Invalid environment '$TEST_ENV'"
  echo "Usage: $0 [local|stg|prd]"
  echo "Default: local"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧪 Testing entrypoint.sh configuration generation..."
echo "   Environment: $TEST_ENV"
echo ""

# Create test output directory
TEST_OUTPUT_DIR="$SCRIPT_DIR/test-output"
mkdir -p "$TEST_OUTPUT_DIR/dynamic"
rm -f "$TEST_OUTPUT_DIR/dynamic/cloudrun-services.yml"

# Set up environment variables based on TEST_ENV
if [ "$TEST_ENV" = "local" ]; then
  # Local environment - no tokens, localhost URLs
  export ENVIRONMENT="local"
  export DOMAIN="localhost"
  export HOME_INDEX_URL="http://localhost:8080"
  export SEO_URL="http://localhost:8080"
  export ANALYTICS_URL="http://localhost:8080"
  export LAB1_URL="http://localhost:80"
  export LAB1_C2_URL="http://localhost:3000"
  export LAB2_URL="http://localhost:80"
  export LAB2_C2_URL="http://localhost:3000"
  export LAB3_URL="http://localhost:80"
  export LAB3_EXTENSION_URL="http://localhost:3000"

  # No tokens for local
  export HOME_INDEX_TOKEN=""
  export SEO_TOKEN=""
  export ANALYTICS_TOKEN=""
  export LAB1_TOKEN=""
  export LAB1_C2_TOKEN=""
  export LAB2_TOKEN=""
  export LAB2_C2_TOKEN=""
  export LAB3_TOKEN=""
  export LAB3_EXTENSION_TOKEN=""

elif [ "$TEST_ENV" = "stg" ]; then
  # Staging environment - with tokens
  export ENVIRONMENT="stg"
  export DOMAIN="labs.stg.pcioasis.com"
  export HOME_INDEX_URL="https://home-index-stg-327539540168.a.run.app"
  export SEO_URL="https://home-seo-stg-327539540168.a.run.app"
  export ANALYTICS_URL="https://labs-analytics-stg-207478017187.us-central1.run.app"
  export LAB1_URL="https://lab-01-basic-magecart-stg-mmwwcfi5za-uc.a.run.app"
  export LAB1_C2_URL="https://lab-01-c2-stg-207478017187.us-central1.run.app"
  export LAB2_URL="https://lab-02-dom-skimming-stg-mmwwcfi5za-uc.a.run.app"
  export LAB2_C2_URL="https://lab-02-c2-stg-207478017187.us-central1.run.app"
  export LAB3_URL="https://lab-03-extension-hijacking-stg-mmwwcfi5za-uc.a.run.app"
  export LAB3_EXTENSION_URL="https://lab-03-extension-server-stg-207478017187.us-central1.run.app"

  # Mock identity tokens (valid JWT format - eyJ...)
  export HOME_INDEX_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2hvbWUtaW5kZXgtc3RnLTMwNzUzOTU0MDE2OC5hLnJ1bi5hcHAiLCJleHAiOjE3MzUxMjM0NTYsImlhdCI6MTczNTEyMzQ1NiwiaXNzIjoiaHR0cHM6Ly9hY2NvdW50cy5nb29nbGUuY29tIiwic3ViIjoic2VydmljZS1hY2NvdW50QHRlc3QuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20ifQ.test_signature_12345"
  export SEO_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2hvbWUtc2VvLXN0Zy0zMDc1Mzk1NDAxNjguYS5ydW4uYXBwIiwiZXhwIjoxNzM1MTIzNDU2LCJpYXQiOjE3MzUxMjM0NTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6InNlcnZpY2UtYWNjb3VudEB0ZXN0LmlhbS5nc2VydmljZWFjY291bnQuY29tIn0.test_signature_67890"
  export ANALYTICS_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYnMtYW5hbHl0aWNzLXN0Zy0yMDc0NzgwMTcxODcudXMtc3RhZ2luZy5ydW4uYXBwIiwiZXhwIjoxNzM1MTIzNDU2LCJpYXQiOjE3MzUxMjM0NTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6InNlcnZpY2UtYWNjb3VudEB0ZXN0LmlhbS5nc2VydmljZWFjY291bnQuY29tIn0.test_signature_abcde"
  export LAB1_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMS1iYXNpYy1tYWdlY2FydC1zdGctbW13d2NmaTV6YS11Yy5hLnJ1bi5hcHAiLCJleHAiOjE3MzUxMjM0NTYsImlhdCI6MTczNTEyMzQ1NiwiaXNzIjoiaHR0cHM6Ly9hY2NvdW50cy5nb29nbGUuY29tIiwic3ViIjoic2VydmljZS1hY2NvdW50QHRlc3QuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20ifQ.test_signature_fghij"
  export LAB1_C2_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMS1jMi1zdGctMjA3NDc4MDE3MTg3LnVzLXN0YWdpbmcucnVuLmFwcCIsImV4cCI6MTczNTEyMzQ1NiwiaWF0IjoxNzM1MTIzNDU2LCJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzZXJ2aWNlLWFjY291bnRAdGVzdC5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSJ9.test_signature_klmno"
  export LAB2_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMi1kb20tc2tpbW1pbmctc3RnLW1td3djZmk1emEtdWMuYS5ydW4uYXBwIiwiZXhwIjoxNzM1MTIzNDU2LCJpYXQiOjE3MzUxMjM0NTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6InNlcnZpY2UtYWNjb3VudEB0ZXN0LmlhbS5nc2VydmljZWFjY291bnQuY29tIn0.test_signature_pqrst"
  export LAB2_C2_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMi1jMi1zdGctMjA3NDc4MDE3MTg3LnVzLXN0YWdpbmcucnVuLmFwcCIsImV4cCI6MTczNTEyMzQ1NiwiaWF0IjoxNzM1MTIzNDU2LCJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzZXJ2aWNlLWFjY291bnRAdGVzdC5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSJ9.test_signature_uvwxy"
  export LAB3_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMy1leHRlbnNpb24taGlqYWNraW5nLXN0Zy1tbXd3Y2ZpNXphLXVjLmEucnVuLmFwcCIsImV4cCI6MTczNTEyMzQ1NiwiaWF0IjoxNzM1MTIzNDU2LCJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzZXJ2aWNlLWFjY291bnRAdGVzdC5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSJ9.test_signature_z1234"
  export LAB3_EXTENSION_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMy1leHRlbnNpb24tc2VydmVyLXN0Zy0yMDc0NzgwMTcxODcudXMtc3RhZ2luZy5ydW4uYXBwIiwiZXhwIjoxNzM1MTIzNDU2LCJpYXQiOjE3MzUxMjM0NTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6InNlcnZpY2UtYWNjb3VudEB0ZXN0LmlhbS5nc2VydmljZWFjY291bnQuY29tIn0.test_signature_56789"

elif [ "$TEST_ENV" = "prd" ]; then
  # Production environment - with tokens
  export ENVIRONMENT="prd"
  export DOMAIN="labs.pcioasis.com"
  export HOME_INDEX_URL="https://home-index-prd-171147998109.us-central1.run.app"
  export SEO_URL="https://home-seo-prd-171147998109.us-central1.run.app"
  export ANALYTICS_URL="https://labs-analytics-prd-207478017187.us-central1.run.app"
  export LAB1_URL="https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app"
  export LAB1_C2_URL="https://lab-01-c2-prd-207478017187.us-central1.run.app"
  export LAB2_URL="https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app"
  export LAB2_C2_URL="https://lab-02-c2-prd-207478017187.us-central1.run.app"
  export LAB3_URL="https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app"
  export LAB3_EXTENSION_URL="https://lab-03-extension-server-prd-207478017187.us-central1.run.app"

  # Mock identity tokens (valid JWT format - eyJ...)
  export HOME_INDEX_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2hvbWUtaW5kZXgtcHJkLTE3MTE0Nzk5ODEwOS51cy1jZW50cmFsMS5ydW4uYXBwIiwiZXhwIjoxNzM1MTIzNDU2LCJpYXQiOjE3MzUxMjM0NTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6InNlcnZpY2UtYWNjb3VudEB0ZXN0LmlhbS5nc2VydmljZWFjY291bnQuY29tIn0.test_signature_prd_12345"
  export SEO_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2hvbWUtc2VvLXByZC0xNzExNDc5OTgxMDkudXMtY2VudHJhbDEucnVuLmFwcCIsImV4cCI6MTczNTEyMzQ1NiwiaWF0IjoxNzM1MTIzNDU2LCJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzZXJ2aWNlLWFjY291bnRAdGVzdC5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSJ9.test_signature_prd_67890"
  export ANALYTICS_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYnMtYW5hbHl0aWNzLXByZC0yMDc0NzgwMTcxODcudXMtc3RhZ2luZy5ydW4uYXBwIiwiZXhwIjoxNzM1MTIzNDU2LCJpYXQiOjE3MzUxMjM0NTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6InNlcnZpY2UtYWNjb3VudEB0ZXN0LmlhbS5nc2VydmljZWFjY291bnQuY29tIn0.test_signature_prd_abcde"
  export LAB1_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMS1iYXNpYy1tYWdlY2FydC1wcmQtbW13d2NmaTV6YS11Yy5hLnJ1bi5hcHAiLCJleHAiOjE3MzUxMjM0NTYsImlhdCI6MTczNTEyMzQ1NiwiaXNzIjoiaHR0cHM6Ly9hY2NvdW50cy5nb29nbGUuY29tIiwic3ViIjoic2VydmljZS1hY2NvdW50QHRlc3QuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20ifQ.test_signature_prd_fghij"
  export LAB1_C2_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMS1jMi1wcmQtMjA3NDc4MDE3MTg3LnVzLXN0YWdpbmcucnVuLmFwcCIsImV4cCI6MTczNTEyMzQ1NiwiaWF0IjoxNzM1MTIzNDU2LCJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzZXJ2aWNlLWFjY291bnRAdGVzdC5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSJ9.test_signature_prd_klmno"
  export LAB2_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMi1kb20tc2tpbW1pbmctcHJkLW1td3djZmk1emEtdWMuYS5ydW4uYXBwIiwiZXhwIjoxNzM1MTIzNDU2LCJpYXQiOjE3MzUxMjM0NTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6InNlcnZpY2UtYWNjb3VudEB0ZXN0LmlhbS5nc2VydmljZWFjY291bnQuY29tIn0.test_signature_prd_pqrst"
  export LAB2_C2_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMi1jMi1wcmQtMjA3NDc4MDE3MTg3LnVzLXN0YWdpbmcucnVuLmFwcCIsImV4cCI6MTczNTEyMzQ1NiwiaWF0IjoxNzM1MTIzNDU2LCJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzZXJ2aWNlLWFjY291bnRAdGVzdC5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSJ9.test_signature_prd_uvwxy"
  export LAB3_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMy1leHRlbnNpb24taGlqYWNraW5nLXByZC1tbXd3Y2ZpNXphLXVjLmEucnVuLmFwcCIsImV4cCI6MTczNTEyMzQ1NiwiaWF0IjoxNzM1MTIzNDU2LCJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzZXJ2aWNlLWFjY291bnRAdGVzdC5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSJ9.test_signature_prd_z1234"
  export LAB3_EXTENSION_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2xhYi0wMy1leHRlbnNpb24tc2VydmVyLXByZC0yMDc0NzgwMTcxODcudXMtc3RhZ2luZy5ydW4uYXBwIiwiZXhwIjoxNzM1MTIzNDU2LCJpYXQiOjE3MzUxMjM0NTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6InNlcnZpY2UtYWNjb3VudEB0ZXN0LmlhbS5nc2VydmljZWFjY291bnQuY29tIn0.test_signature_prd_56789"
fi

# Override get_identity_token to return from env vars (skip metadata server call)
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

export -f get_identity_token

# Create a modified entrypoint that uses test directory
# Replace the path and comment out the original get_identity_token, inject our mock
sed "s|/etc/traefik/dynamic|$TEST_OUTPUT_DIR/dynamic|g" entrypoint.sh > "$TEST_OUTPUT_DIR/entrypoint-test.sh"

# Inject our mock get_identity_token function right after the shebang
# and comment out the original one
cat > "$TEST_OUTPUT_DIR/inject-mock.sh" << 'INJECT'
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
INJECT

# Insert mock function after shebang and comment out original
awk '
  NR == 1 {
    print
    # Print the mock function
    while ((getline line < "'"$TEST_OUTPUT_DIR/inject-mock.sh"'") > 0) {
      if (line !~ /^#!/) print line
    }
    close("'"$TEST_OUTPUT_DIR/inject-mock.sh"'")
    next
  }
  /^get_identity_token\(\) \{/ {
    # Comment out the original function
    print "# " $0 " # COMMENTED OUT FOR TESTING"
    in_func = 1
    next
  }
  in_func {
    if (/^}$/ && !/^[[:space:]]/) {
      print "# " $0 " # END OF COMMENTED FUNCTION"
      in_func = 0
    } else {
      print "# " $0
    }
    next
  }
  { print }
' "$TEST_OUTPUT_DIR/entrypoint-test.sh" > "$TEST_OUTPUT_DIR/entrypoint-test-tmp.sh"
mv "$TEST_OUTPUT_DIR/entrypoint-test-tmp.sh" "$TEST_OUTPUT_DIR/entrypoint-test.sh"

chmod +x "$TEST_OUTPUT_DIR/entrypoint-test.sh"

# Override exec to stop after config generation
exec() {
  echo ""
  echo "✅ Config generation complete (test mode - Traefik not started)"
  return 0
}

export -f exec

# Run the test entrypoint
echo "Running entrypoint.sh in test mode..."
echo ""

# Source the test entrypoint (it will generate config then call exec which we've overridden)
bash "$TEST_OUTPUT_DIR/entrypoint-test.sh" 2>&1 | tee "$TEST_OUTPUT_DIR/test-output.log" || {
  # Check if config was generated even if exec failed
  if [ -f "$TEST_OUTPUT_DIR/dynamic/cloudrun-services.yml" ]; then
    echo ""
    echo "⚠️  Script exited but config was generated, continuing validation..."
  else
    echo ""
    echo "❌ ERROR: Script failed and config was not generated"
    echo "Check test-output.log for details"
    exit 1
  fi
}

CONFIG_FILE="$TEST_OUTPUT_DIR/dynamic/cloudrun-services.yml"

# Validate
echo ""
echo "🔍 Validating generated configuration..."
echo ""

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ ERROR: Config file was not generated!"
  echo "   Expected: $CONFIG_FILE"
  echo "   Check test-output.log for errors"
  exit 1
fi

echo "✅ Config file exists: $CONFIG_FILE"
echo ""

# Check if Authorization header is present (only for stg/prd)
if [ "$TEST_ENV" = "local" ]; then
  echo "  ℹ️  Local environment - no auth tokens expected"
  if grep -q "Authorization.*Bearer" "$CONFIG_FILE"; then
    echo "  ⚠️  WARNING: Authorization header found in local environment (unexpected)"
    echo "     This might indicate tokens are being generated when they shouldn't be"
  else
    echo "  ✅ No Authorization headers (expected for local)"
  fi
  echo ""
else
  # For stg/prd, we expect auth headers
  if grep -q "Authorization.*Bearer" "$CONFIG_FILE"; then
    echo "  ✅ Authorization header found in middleware"
    echo ""
    echo "  home-index-auth middleware:"
    grep -A 5 "home-index-auth:" "$CONFIG_FILE" | head -6
    echo ""
  else
    echo "  ❌ ERROR: Authorization header NOT found in middleware!"
    echo "     Expected for $TEST_ENV environment"
    echo ""
    echo "  Generated config (first 50 lines):"
    head -50 "$CONFIG_FILE"
    exit 1
  fi
fi

# Validate YAML syntax
if command -v python3 &> /dev/null; then
  if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
    echo "  ✅ YAML syntax is valid"
  else
    echo "  ❌ ERROR: YAML syntax is invalid!"
    python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>&1 | head -10
    exit 1
  fi
elif command -v yq &> /dev/null; then
  if yq eval '.' "$CONFIG_FILE" > /dev/null 2>&1; then
    echo "  ✅ YAML syntax is valid"
  else
    echo "  ❌ ERROR: YAML syntax is invalid!"
    yq eval '.' "$CONFIG_FILE" 2>&1 | head -10
    exit 1
  fi
else
  echo "  ⚠️  No YAML validator found (python3 or yq), skipping validation"
fi

# Check router configuration
echo ""
echo "🔍 Checking router configuration..."
ROUTER_CONFIG=$(grep -A 8 "^    home-index:" "$CONFIG_FILE" | head -9)

if [ "$TEST_ENV" = "local" ]; then
  # Local should NOT have auth middleware
  if echo "$ROUTER_CONFIG" | grep -q "home-index-auth"; then
    echo "  ⚠️  WARNING: home-index router uses home-index-auth middleware in local environment"
    echo "     This might indicate tokens are being generated when they shouldn't be"
  else
    echo "  ✅ home-index router does NOT use auth middleware (expected for local)"
  fi
  echo ""
  echo "  Router configuration:"
  echo "$ROUTER_CONFIG"
else
  # stg/prd should have auth middleware
  if echo "$ROUTER_CONFIG" | grep -q "home-index-auth"; then
    echo "  ✅ home-index router uses home-index-auth middleware"
    echo ""
    echo "  Router configuration:"
    echo "$ROUTER_CONFIG"
  else
    echo "  ❌ ERROR: home-index router does NOT use home-index-auth middleware!"
    echo "     Expected for $TEST_ENV environment"
    echo ""
    echo "  Router configuration:"
    echo "$ROUTER_CONFIG"
    exit 1
  fi
fi

echo ""
echo "✅ All tests passed!"
echo ""
echo "Generated config saved to: $CONFIG_FILE"
echo "You can inspect it with: cat $CONFIG_FILE"
