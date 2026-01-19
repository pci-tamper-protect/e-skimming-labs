#!/bin/bash
# Check if Google Cloud credentials are fresh and valid
# Usage: source ./deploy/check-credentials.sh
#        check_credentials  # Returns 0 if valid, 1 if expired/invalid
#
# This script checks:
# 1. gcloud auth is active
# 2. Application Default Credentials (ADC) exist
# 3. ADC are not expired (can generate access token)
# 4. Docker is authenticated to Artifact Registry

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

check_credentials() {
  local verbose="${1:-true}"
  local errors=0

  # 1. Check gcloud auth
  if [ "$verbose" = "true" ]; then
    echo "🔐 Checking Google Cloud credentials..."
  fi

  CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
  if [ -z "${CURRENT_USER}" ]; then
    if [ "$verbose" = "true" ]; then
      echo -e "${RED}❌ No active gcloud authentication found${NC}"
      echo "   Run: gcloud auth login"
    fi
    errors=$((errors + 1))
  else
    if [ "$verbose" = "true" ]; then
      echo -e "${GREEN}   ✅ gcloud auth: ${CURRENT_USER}${NC}"
    fi
  fi

  # 2. Check Application Default Credentials exist
  ADC_FILE="${HOME}/.config/gcloud/application_default_credentials.json"
  if [ ! -f "$ADC_FILE" ]; then
    if [ "$verbose" = "true" ]; then
      echo -e "${RED}❌ Application Default Credentials not found${NC}"
      echo "   Run: gcloud auth application-default login"
    fi
    errors=$((errors + 1))
  else
    if [ "$verbose" = "true" ]; then
      echo -e "${GREEN}   ✅ ADC file exists${NC}"
    fi
  fi

  # 3. Check ADC can generate access token (tests if not expired)
  if ! gcloud auth application-default print-access-token &>/dev/null; then
    if [ "$verbose" = "true" ]; then
      echo -e "${RED}❌ Application Default Credentials are expired or invalid${NC}"
      echo "   Run: gcloud auth application-default login"
      echo ""
      echo -e "${YELLOW}   ⚠️  Note: Expired ADC can cause weird routing behavior!${NC}"
      echo "   When ADC expires, the Traefik provider can't fetch identity tokens,"
      echo "   causing routes to fail authentication. This may result in:"
      echo "   - Lab pages showing the home page instead of lab content"
      echo "   - 401 Unauthorized errors"
      echo "   - Routes appearing to work but serving wrong content"
    fi
    errors=$((errors + 1))
  else
    if [ "$verbose" = "true" ]; then
      echo -e "${GREEN}   ✅ ADC can generate access token${NC}"
    fi
  fi

  # 4. Check Docker auth (optional, only warn)
  if [ "$verbose" = "true" ]; then
    # Check if docker config has the registry
    if [ -f "${HOME}/.docker/config.json" ]; then
      if grep -q "us-central1-docker.pkg.dev" "${HOME}/.docker/config.json" 2>/dev/null; then
        echo -e "${GREEN}   ✅ Docker authenticated to Artifact Registry${NC}"
      else
        echo -e "${YELLOW}   ⚠️  Docker may not be authenticated to Artifact Registry${NC}"
        echo "   Run: gcloud auth configure-docker us-central1-docker.pkg.dev"
      fi
    else
      echo -e "${YELLOW}   ⚠️  Docker config not found${NC}"
      echo "   Run: gcloud auth configure-docker us-central1-docker.pkg.dev"
    fi
  fi

  if [ $errors -gt 0 ]; then
    if [ "$verbose" = "true" ]; then
      echo ""
      echo -e "${RED}❌ Credential check failed with $errors error(s)${NC}"
      echo ""
      echo "To fix, run:"
      echo "  gcloud auth login"
      echo "  gcloud auth application-default login"
      echo "  gcloud auth configure-docker us-central1-docker.pkg.dev"
    fi
    return 1
  fi

  if [ "$verbose" = "true" ]; then
    echo ""
    echo -e "${GREEN}✅ All credentials are valid${NC}"
  fi
  return 0
}

# Check if ADC will expire soon (within 10 minutes)
# This is a heuristic based on file modification time
check_adc_freshness() {
  local verbose="${1:-true}"
  local ADC_FILE="${HOME}/.config/gcloud/application_default_credentials.json"
  
  if [ ! -f "$ADC_FILE" ]; then
    return 1
  fi

  # Get file modification time (seconds since epoch)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    FILE_MTIME=$(stat -f %m "$ADC_FILE" 2>/dev/null || echo "0")
  else
    # Linux
    FILE_MTIME=$(stat -c %Y "$ADC_FILE" 2>/dev/null || echo "0")
  fi

  CURRENT_TIME=$(date +%s)
  AGE_SECONDS=$((CURRENT_TIME - FILE_MTIME))
  AGE_HOURS=$((AGE_SECONDS / 3600))

  # ADC tokens typically expire after 1 hour
  # Warn if older than 50 minutes
  if [ $AGE_SECONDS -gt 3000 ]; then
    if [ "$verbose" = "true" ]; then
      echo -e "${YELLOW}   ⚠️  ADC file is ${AGE_HOURS}h old - tokens may expire soon${NC}"
      echo "   Consider refreshing: gcloud auth application-default login"
    fi
  fi
}

# Run check if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_credentials
  exit $?
fi
