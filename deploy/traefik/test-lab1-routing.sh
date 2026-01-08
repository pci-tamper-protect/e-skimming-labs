#!/bin/bash
# Test script to diagnose lab1 routing issues in staging
# Tests each step: route generation, token fetching, service accessibility

set -e

ENVIRONMENT="${ENVIRONMENT:-stg}"
PROJECT_ID="${LABS_PROJECT_ID:-labs-${ENVIRONMENT}}"
REGION="${REGION:-us-central1}"

echo "🔍 Testing Lab1 Routing in ${ENVIRONMENT}"
echo "=========================================="
echo ""

# Step 1: Check if lab1 service exists and get its URL
echo "Step 1: Checking lab1 Cloud Run service..."
LAB1_SERVICE="lab-01-basic-magecart-${ENVIRONMENT}"
if gcloud run services describe "${LAB1_SERVICE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)" > /tmp/lab1-url.txt 2>/dev/null; then
  LAB1_URL=$(cat /tmp/lab1-url.txt)
  echo "✅ Found service: ${LAB1_SERVICE}"
  echo "   URL: ${LAB1_URL}"
else
  echo "❌ Service ${LAB1_SERVICE} not found"
  exit 1
fi
echo ""

# Step 2: Check service labels
echo "Step 2: Checking Traefik labels on service..."
gcloud run services describe "${LAB1_SERVICE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="json" | jq -r '.spec.template.metadata.labels | to_entries[] | select(.key | startswith("traefik_")) | "\(.key)=\(.value)"' > /tmp/lab1-labels.txt
echo "Traefik labels:"
cat /tmp/lab1-labels.txt
echo ""

# Step 3: Check if service is public or requires auth
echo "Step 3: Checking service IAM policy..."
IAM_POLICY=$(gcloud run services get-iam-policy "${LAB1_SERVICE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="json" 2>/dev/null || echo "{}")
ALL_USERS_ACCESS=$(echo "$IAM_POLICY" | jq -r '.bindings[]? | select(.role == "roles/run.invoker") | .members[]? | select(. == "allUsers")' || echo "")
if [ -n "$ALL_USERS_ACCESS" ]; then
  echo "⚠️  Service is PUBLIC (allUsers has access)"
else
  echo "✅ Service is PRIVATE (requires authentication)"
fi
echo ""

# Step 4: Test generating routes from labels
echo "Step 4: Testing route generation..."
export ENVIRONMENT="${ENVIRONMENT}"
export LABS_PROJECT_ID="${PROJECT_ID}"
export HOME_PROJECT_ID="labs-home-${ENVIRONMENT}"
export REGION="${REGION}"
./generate-routes-from-labels.sh /tmp/test-routes.yml 2>&1 | tee /tmp/route-gen.log
echo ""

# Step 5: Check if lab1 routes were generated
echo "Step 5: Checking generated routes..."
if [ -f /tmp/test-routes.yml ]; then
  echo "Routes file generated. Checking lab1 routes:"
  echo ""
  echo "--- Lab1 Routers ---"
  grep -A 10 "lab1" /tmp/test-routes.yml | head -30 || echo "No lab1 routes found"
  echo ""
  echo "--- Lab1 Services ---"
  grep -A 5 "lab1:" /tmp/test-routes.yml | grep -A 5 "services:" || echo "No lab1 services found"
  echo ""
  echo "--- Lab1 Auth Middlewares ---"
  grep -A 3 "lab1.*auth:" /tmp/test-routes.yml || echo "No lab1 auth middlewares found"
  echo ""
  echo "--- Checking if routers use auth middleware ---"
  echo "Lab1 routers and their middlewares:"
  grep -B 2 -A 5 "lab1" /tmp/test-routes.yml | grep -A 5 "middlewares:" | head -20 || echo "No lab1 router middlewares found"
else
  echo "❌ Routes file not generated"
fi
echo ""

# Step 6: Test fetching identity token
echo "Step 6: Testing identity token fetch..."
if command -v gcloud &> /dev/null; then
  echo "Attempting to fetch token for ${LAB1_URL}..."
  TOKEN=$(gcloud auth print-identity-token --audience="${LAB1_URL}" 2>/dev/null || echo "")
  if [ -n "$TOKEN" ] && [[ "$TOKEN" =~ ^eyJ ]]; then
    echo "✅ Token fetched successfully (${#TOKEN} chars)"
    echo "   Token preview: ${TOKEN:0:50}..."
  else
    echo "❌ Failed to fetch token"
    echo "   This might be expected if running locally"
  fi
else
  echo "⚠️  gcloud not available, skipping token test"
fi
echo ""

# Step 7: Test direct service access (if token available)
if [ -n "$TOKEN" ] && [[ "$TOKEN" =~ ^eyJ ]]; then
  echo "Step 7: Testing direct service access with token..."
  echo "Testing ${LAB1_URL}/..."
  HTTP_CODE=$(curl -s -o /tmp/lab1-response.txt -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    "${LAB1_URL}/" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Service accessible with token"
  else
    echo "❌ Service returned HTTP ${HTTP_CODE}"
    echo "   Response preview:"
    head -20 /tmp/lab1-response.txt
  fi
  echo ""

  echo "Testing ${LAB1_URL}/c2..."
  HTTP_CODE_C2=$(curl -s -o /tmp/lab1-c2-response.txt -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    "${LAB1_URL}/c2" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE_C2" = "200" ]; then
    echo "✅ C2 endpoint accessible with token"
  else
    echo "❌ C2 endpoint returned HTTP ${HTTP_CODE_C2}"
    echo "   Response preview:"
    head -20 /tmp/lab1-c2-response.txt
  fi
  echo ""

  echo "Testing ${LAB1_URL}/css/style.css..."
  HTTP_CODE_CSS=$(curl -s -o /tmp/lab1-css-response.txt -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    "${LAB1_URL}/css/style.css" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE_CSS" = "200" ]; then
    echo "✅ CSS file accessible with token"
  else
    echo "❌ CSS file returned HTTP ${HTTP_CODE_CSS}"
    echo "   Response preview:"
    head -20 /tmp/lab1-css-response.txt
  fi
else
  echo "Step 7: Skipping direct service access (no token available)"
fi
echo ""

# Step 8: Check Traefik service
echo "Step 8: Checking Traefik service configuration..."
TRAEFIK_SERVICE="traefik-${ENVIRONMENT}"
if gcloud run services describe "${TRAEFIK_SERVICE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(status.url)" > /tmp/traefik-url.txt 2>/dev/null; then
  TRAEFIK_URL=$(cat /tmp/traefik-url.txt)
  echo "✅ Traefik service found: ${TRAEFIK_URL}"

  # Check Traefik environment variables
  echo "Checking Traefik environment variables..."
  gcloud run services describe "${TRAEFIK_SERVICE}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    --format="json" | jq -r '.spec.template.spec.containers[0].env[]? | select(.name | startswith("LAB")) | "\(.name)=\(.value)"' || echo "No LAB* env vars found"
else
  echo "❌ Traefik service not found"
fi
echo ""

echo "=========================================="
echo "✅ Diagnostic complete"
echo ""
echo "Next steps:"
echo "1. Check if routes are generated correctly in /tmp/test-routes.yml"
echo "2. Verify auth middlewares are created for lab1"
echo "3. Check if Traefik has LAB1_URL environment variable set"
echo "4. Test accessing via Traefik: ${TRAEFIK_URL:-<traefik-url>}/lab1/c2"
