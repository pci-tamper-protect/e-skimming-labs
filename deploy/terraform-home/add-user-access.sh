#!/bin/bash
# Add individual user access to staging Cloud Run services
# This is a temporary workaround if the user is not in the required groups

set -euo pipefail

PROJECT_ID="${HOME_PROJECT_ID:-labs-home-stg}"
REGION="us-central1"
USER_EMAIL="${1:-kesten.broughton@pcioasis.com}"

echo "🔧 Adding user access for $USER_EMAIL to staging services in project $PROJECT_ID"
echo ""

SERVICES=("home-index-stg" "home-seo-stg")

for SERVICE in "${SERVICES[@]}"; do
  echo "📋 Processing service: $SERVICE"
  
  # Check if service exists
  if ! gcloud run services describe "$SERVICE" \
    --region="$REGION" \
    --project="$PROJECT_ID" &>/dev/null; then
    echo "   ⚠️  Service $SERVICE does not exist, skipping..."
    echo ""
    continue
  fi
  
  # Check if binding already exists
  if gcloud run services get-iam-policy "$SERVICE" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --flatten="bindings[].members" \
    --filter="bindings.members:user:$USER_EMAIL AND bindings.role:roles/run.invoker" \
    --format="value(bindings.members)" | grep -q "user:$USER_EMAIL"; then
    echo "   ✅ $USER_EMAIL already has access"
  else
    echo "   ➕ Adding $USER_EMAIL..."
    gcloud run services add-iam-policy-binding "$SERVICE" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --member="user:$USER_EMAIL" \
      --role="roles/run.invoker" || {
      echo "   ❌ Failed to add $USER_EMAIL"
      exit 1
    }
  fi
  echo ""
done

echo "✅ Done! User access updated."
echo ""
echo "💡 To verify, try accessing:"
echo "   https://home-index-stg-327539540168.us-central1.run.app/"

