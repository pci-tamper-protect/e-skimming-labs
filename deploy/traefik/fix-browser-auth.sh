#!/bin/bash
# Fix browser authentication for labs.stg.pcioasis.com
# This script helps set up IAM and provides instructions for browser access

set -e

USER_EMAIL="${1:-$(gcloud config get-value account 2>/dev/null || echo '')}"
ENVIRONMENT="stg"
PROJECT_ID="labs-stg"
SERVICE_NAME="traefik-stg"
REGION="us-central1"

if [ -z "$USER_EMAIL" ]; then
  echo "❌ Error: Could not determine your email address"
  echo "   Please provide it as an argument: $0 your-email@domain.com"
  exit 1
fi

echo "🔧 Fixing browser authentication for labs.stg.pcioasis.com"
echo "   User: $USER_EMAIL"
echo ""

# Check current IAM policy
echo "1. Checking current IAM bindings..."
CURRENT_POLICY=$(gcloud run services get-iam-policy "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="json" 2>/dev/null)

if [ -z "$CURRENT_POLICY" ]; then
  echo "   ❌ Failed to get IAM policy"
  exit 1
fi

# Check if user already has access
HAS_ACCESS=$(echo "$CURRENT_POLICY" | jq -r ".bindings[] | select(.role == \"roles/run.invoker\") | .members[]" | grep -c "user:$USER_EMAIL" || echo "0")

if [ "$HAS_ACCESS" -gt 0 ]; then
  echo "   ✅ User already has roles/run.invoker"
else
  echo "   ⚠️  User does NOT have direct access"
  echo ""
  read -p "   Add direct user access? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   Adding user access..."
    gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --member="user:$USER_EMAIL" \
      --role="roles/run.invoker"
    echo "   ✅ User access added!"
  fi
fi

echo ""
echo "2. Checking group membership..."
GROUPS=("2025-interns@pcioasis.com" "core-eng@pcioasis.com")
IN_GROUP=false

for group in "${GROUPS[@]}"; do
  if gcloud identity groups memberships check-transitive-membership \
    --group-email="$group" \
    --member-email="$USER_EMAIL" 2>/dev/null; then
    echo "   ✅ User is in group: $group"
    IN_GROUP=true
  fi
done

if [ "$IN_GROUP" = false ]; then
  echo "   ⚠️  User is NOT in any allowed groups"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Browser Authentication Instructions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To access labs.stg.pcioasis.com in your browser:"
echo ""
echo "1. Sign in to Google in your browser:"
echo "   - Go to: https://myaccount.google.com"
echo "   - Make sure you're signed in with: $USER_EMAIL"
echo "   - If not, sign out and sign in with the correct account"
echo ""
echo "2. Clear browser cache/cookies for labs.stg.pcioasis.com:"
echo "   - Chrome/Edge: Settings > Privacy > Clear browsing data"
echo "   - Firefox: Settings > Privacy > Clear Data"
echo "   - Or use incognito/private browsing mode"
echo ""
echo "3. Access the domain:"
echo "   - Go to: https://labs.stg.pcioasis.com"
echo "   - You should be redirected to Google sign-in if not authenticated"
echo "   - After signing in, you should have access"
echo ""
echo "4. If you still get '403 Forbidden' after signing in:"
echo "   - Check that you're signed in with the correct Google account"
echo "   - Verify IAM permissions were applied (run this script again)"
echo "   - Try a different browser or incognito mode"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Alternative: Use the proxy for local testing"
echo ""
echo "   The proxy at 127.0.0.1:8081 works without browser authentication:"
echo "   gcloud run services proxy traefik-stg --region=us-central1 --project=labs-stg --port=8081"
echo ""
echo "   However, links on the page will still navigate to labs.stg.pcioasis.com"
echo "   which requires browser authentication."
echo ""
