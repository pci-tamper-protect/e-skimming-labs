#!/usr/bin/env bash
# Debug script for lab auth (ForwardAuth) not working
# Run with: ./deploy/traefik/debug-lab-auth.sh stg
# Or from repo root: ./deploy/traefik/debug-lab-auth.sh stg
#
# Prerequisites: gcloud authenticated, proxy running on 8082 (or set PROXY_PORT)

set -e

ENV="${1:-stg}"
PROXY_PORT="${PROXY_PORT:-8082}"
REGION="us-central1"

if [ "$ENV" = "prd" ]; then
  LABS_PROJECT="labs-prd"
  HOME_PROJECT="labs-home-prd"
else
  LABS_PROJECT="labs-stg"
  HOME_PROJECT="labs-home-stg"
fi

echo "=========================================="
echo "Lab Auth Debug - Environment: $ENV"
echo "=========================================="
echo ""

# 1. Check HOME_INDEX_URL on Traefik service
echo "1. Traefik HOME_INDEX_URL (must be set for auth-forward.yml):"
HOME_INDEX_ENV=$(gcloud run services describe "traefik-${ENV}" \
  --region="$REGION" \
  --project="$LABS_PROJECT" \
  --format='yaml(spec.template.spec.containers[0].env)' 2>/dev/null | grep -A1 "HOME_INDEX_URL" || echo "NOT FOUND")
if echo "$HOME_INDEX_ENV" | grep -q "value:"; then
  echo "$HOME_INDEX_ENV"
  if echo "$HOME_INDEX_ENV" | grep -q "__HOME_INDEX_URL__"; then
    echo "   ❌ BUG: Placeholder __HOME_INDEX_URL__ not substituted! Run full redeploy or fix workflow sed."
  elif echo "$HOME_INDEX_ENV" | grep -q "https://"; then
    echo "   ✅ HOME_INDEX_URL looks correct"
  fi
else
  echo "   ❌ HOME_INDEX_URL not set on Traefik. Run: ./deploy/traefik/set-home-index-url.sh $ENV"
fi
echo ""

# 2a. Check USER_AUTH_ENABLED on provider sidecar (provider filters lab1-auth-check when false)
echo "2a. Provider USER_AUTH_ENABLED (must be true for lab1-auth-check in router middlewares):"
PROVIDER_AUTH=$(gcloud run services describe "traefik-${ENV}" \
  --region="$REGION" \
  --project="$LABS_PROJECT" \
  --format='yaml(spec.template.spec.containers)' 2>/dev/null | grep -A2 "USER_AUTH_ENABLED" | head -3 || echo "NOT FOUND")
if echo "$PROVIDER_AUTH" | grep -qE 'value:.*true'; then
  echo "   ✅ USER_AUTH_ENABLED=true (provider will keep lab1-auth-check in router)"
elif echo "$PROVIDER_AUTH" | grep -q "USER_AUTH_ENABLED"; then
  echo "   ❌ USER_AUTH_ENABLED not 'true' - provider filters out lab1-auth-check"
  echo "$PROVIDER_AUTH"
else
  echo "   ❌ USER_AUTH_ENABLED not found on provider container (cloudrun-sidecar.yaml)"
fi
echo ""

# 2b. Check Traefik can invoke home-index (cross-project)
echo "2b. Traefik invoker permission on home-index:"
if gcloud run services get-iam-policy "home-index-${ENV}" \
  --region="$REGION" \
  --project="$HOME_PROJECT" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:traefik-${ENV}@${LABS_PROJECT}.iam.gserviceaccount.com" \
  --format="table(bindings.role)" 2>/dev/null | grep -q "run.invoker"; then
  echo "   ✅ traefik-${ENV}@${LABS_PROJECT} has roles/run.invoker on home-index-${ENV}"
else
  echo "   ❌ Traefik SA missing invoker on home-index. Run: cd deploy/terraform-home && terraform apply"
fi
echo ""

# 3. Check lab1 router and middlewares (requires proxy)
# Naming: lab1-auth = Cloud Run IAM token (backend invocation); lab1-auth-check = ForwardAuth (user JWT)
# lab1 router MUST have lab1-auth-check for user auth; lab1-c2 has lab1-c2-server-auth (different backend)
echo "3. Lab1 router config (via proxy at localhost:${PROXY_PORT}):"
if curl -sf --max-time 3 "http://127.0.0.1:${PROXY_PORT}/api/http/routers" 2>/dev/null | jq -r '.[] | select(.name | contains("lab1")) | select(.name | contains("static") | not) | "\(.name): middlewares=\(.middlewares | join(", "))"' 2>/dev/null | head -5; then
  echo "   Expected: lab1 has lab1-auth-check@file (user auth); lab1-c2 has lab1-c2-server-auth@file (backend auth)"
  LAB1_MW=$(curl -sf --max-time 3 "http://127.0.0.1:${PROXY_PORT}/api/http/routers" 2>/dev/null | jq -r '.[] | select(.name | contains("lab1")) | select(.name | contains("static") | not) | .middlewares | join(" ")' 2>/dev/null | head -1)
  if echo "$LAB1_MW" | grep -q "lab1-auth-check"; then
    echo "   ✅ lab1 has lab1-auth-check (user auth enabled)"
  else
    echo "   ❌ lab1 missing lab1-auth-check - set USER_AUTH_ENABLED=true on provider container"
  fi
else
  echo "   ⚠️  Proxy not running or Traefik API not accessible."
  echo "   Start proxy: gcloud run services proxy traefik-${ENV} --region=$REGION --project=$LABS_PROJECT --port=$PROXY_PORT"
  echo "   Then: curl -s http://127.0.0.1:${PROXY_PORT}/api/http/routers | jq '.[] | select(.name | contains(\"lab1\")) | {name, middlewares}'"
fi
echo ""

# 4. Check lab1-auth-check middleware exists
echo "4. lab1-auth-check middleware (via proxy):"
if curl -sf --max-time 3 "http://127.0.0.1:${PROXY_PORT}/api/http/middlewares" 2>/dev/null | jq -r '.[] | select(.name | contains("lab1-auth-check")) | .name' 2>/dev/null | head -1; then
  echo "   ✅ lab1-auth-check middleware exists"
  curl -sf --max-time 3 "http://127.0.0.1:${PROXY_PORT}/api/http/middlewares" 2>/dev/null | jq '.[] | select(.name | contains("lab1-auth-check")) | .forwardAuth.address' 2>/dev/null || true
else
  echo "   ❌ lab1-auth-check not found. auth-forward.yml may not have been written (check HOME_INDEX_URL, Traefik logs)"
fi
echo ""

# 5. Force new revision (if HOME_INDEX_URL was just set)
echo "5. To force new Traefik instances (pick up env change):"
echo "   gcloud run services update traefik-${ENV} --region=$REGION --project=$LABS_PROJECT --update-env-vars=FORCE_RESTART=\$(date +%s)"
echo "   (Use --update-env-vars, NOT --set-env-vars, or you will wipe HOME_INDEX_URL and other env vars)"
echo ""

# 6. Check provider finds home-index
echo "6. Provider logs (home-index discovery):"
echo "   gcloud logging read \"resource.type=cloud_run_revision AND resource.labels.service_name=traefik-${ENV} AND textPayload=~\\\"home-index\\\"\" --limit=5 --project=$LABS_PROJECT --format='value(textPayload)'"
echo ""

# 7. Check home-index ENABLE_AUTH (auth disabled = 200, no redirect)
echo "7. Home-index ENABLE_AUTH (must be true for auth to run):"
HOME_INDEX_AUTH=$(gcloud run services describe "home-index-${ENV}" \
  --region="$REGION" \
  --project="$HOME_PROJECT" \
  --format='yaml(spec.template.spec.containers[0].env)' 2>/dev/null | grep -A1 "ENABLE_AUTH" || echo "NOT FOUND")
if echo "$HOME_INDEX_AUTH" | grep -qE 'value:.*true'; then
  echo "   ✅ ENABLE_AUTH=true"
else
  echo "   ❌ ENABLE_AUTH not 'true' - auth disabled, /api/auth/check returns 200!"
  echo "$HOME_INDEX_AUTH"
fi
echo ""

# 8. Test /lab1 response (requires proxy)
echo "8. /lab1 response (via proxy):"
echo "   GET (expected 302 when unauthenticated):"
if curl -sf --max-time 5 -o /dev/null -w "   HTTP %{http_code} -> %{redirect_url}\n" "http://127.0.0.1:${PROXY_PORT}/lab1?force_auth=true" 2>/dev/null; then
  :
else
  echo "   ⚠️  Proxy not running"
fi
echo "   HEAD (curl -I; some ForwardAuth setups handle HEAD differently):"
if curl -sf --max-time 5 -I -o /dev/null -w "   HTTP %{http_code}\n" "http://127.0.0.1:${PROXY_PORT}/lab1?force_auth=true" 2>/dev/null; then
  :
fi
echo ""

# 9. Home-index auth/check logs (last 2 min)
echo "9. Recent home-index /api/auth/check logs:"
echo "   gcloud logging read \"resource.type=cloud_run_revision AND resource.labels.service_name=home-index-${ENV} AND textPayload=~\\\"auth/check\\\"\" --limit=5 --project=$HOME_PROJECT --format='value(textPayload)' --freshness=2m"
echo ""

echo "=========================================="
echo "Quick fixes:"
echo "  - 200 instead of 302:"
echo "    1. home-index ENABLE_AUTH must be true (step 7)"
echo "    2. Try GET not HEAD: curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:${PROXY_PORT}/lab1?force_auth=true'"
echo "    3. If GET also returns 200, check step 9 - if no auth/check logs, request is not reaching home-index"
echo "  - lab1-auth-check missing: cloudrun-sidecar.yaml must have USER_AUTH_ENABLED=true on provider"
echo "  - auth-forward.yml not written: Ensure workflow sed substitutes __HOME_INDEX_URL__"
echo "  - Set ENABLE_AUTH: gcloud run services update home-index-${ENV} --region=$REGION --project=$HOME_PROJECT --update-env-vars=ENABLE_AUTH=true"
echo "  - Or run: ./deploy/traefik/set-home-index-url.sh $ENV"
echo "  - Wait 2-3 min for new instances to receive traffic after changes"
echo "=========================================="
