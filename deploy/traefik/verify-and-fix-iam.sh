#!/bin/bash
# Verify and fix IAM permissions for Traefik staging
# Usage: ./verify-and-fix-iam.sh [your-email@domain.com]

set -e

USER_EMAIL="${1:-$(gcloud config get-value account)}"
ENVIRONMENT="stg"
PROJECT_ID="labs-stg"
SERVICE_NAME="traefik-stg"
REGION="us-central1"

echo "🔍 Verifying IAM permissions for Traefik staging..."
echo "   User: $USER_EMAIL"
echo "   Service: $SERVICE_NAME"
echo ""

# Check current IAM policy
echo "Current IAM bindings:"
gcloud run services get-iam-policy "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="table(bindings.role,bindings.members)" || {
  echo "❌ Failed to get IAM policy"
  exit 1
}

echo ""
echo "Checking if user has access..."

# Check if user is in the allowed groups
echo ""
echo "Checking group membership..."
GROUPS=("2025-interns@pcioasis.com" "core-eng@pcioasis.com")
IN_GROUP=false

for group in "${GROUPS[@]}"; do
  if gcloud identity groups memberships check-transitive-membership \
    --group-email="$group" \
    --member-email="$USER_EMAIL" 2>/dev/null; then
    echo "  ✅ User is in group: $group"
    IN_GROUP=true
  else
    echo "  ❌ User is NOT in group: $group"
  fi
done

echo ""
if [ "$IN_GROUP" = true ]; then
  echo "✅ User is in at least one allowed group"
  echo ""
  echo "For browser access, you need to:"
  echo "1. Sign in to Google in your browser with: $USER_EMAIL"
  echo "2. Clear browser cache/cookies for labs.stg.pcioasis.com"
  echo "3. Access: https://labs.stg.pcioasis.com"
  echo ""
  echo "The browser will redirect to Google sign-in if not already authenticated."
else
  echo "⚠️  User is NOT in any allowed groups"
  echo ""
  read -p "Do you want to add direct user access? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Adding user access..."
    gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --member="user:$USER_EMAIL" \
      --role="roles/run.invoker"

    echo ""
    echo "✅ User access added!"
    echo ""
    echo "Now:"
    echo "1. Sign in to Google in your browser with: $USER_EMAIL"
    echo "2. Clear browser cache/cookies for labs.stg.pcioasis.com"
    echo "3. Access: https://labs.stg.pcioasis.com"
  fi
fi

echo ""
echo "📝 Browser Authentication Notes:"
echo ""
echo "Cloud Run IAM requires browser-based Google authentication:"
echo "1. When you access https://labs.stg.pcioasis.com, Google will:"
echo "   - Check if you're signed in to Google in the browser"
echo "   - If not, redirect to Google sign-in"
echo "   - Verify your IAM permissions"
echo "   - Grant access if you have roles/run.invoker"
echo ""
echo "2. Make sure you're signed in to the CORRECT Google account:"
echo "   - Go to: https://myaccount.google.com"
echo "   - Verify you're using: $USER_EMAIL"
echo ""
echo "3. If you still get 'forbidden' after signing in:"
echo "   - Clear cookies for labs.stg.pcioasis.com"
echo "   - Try incognito/private browsing mode"
echo "   - Check that IAM binding was applied (run this script again)"
