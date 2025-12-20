#!/bin/bash
# Fix IAM bindings for home-index-stg and home-seo-stg services
# Adds group access if missing

set -euo pipefail

PROJECT_ID="${HOME_PROJECT_ID:-labs-home-stg}"
REGION="us-central1"

echo "🔧 Fixing IAM bindings for staging services in project $PROJECT_ID"
echo ""

SERVICES=("home-index-stg" "home-seo-stg")
GROUPS=("group:core-eng@pcioasis.com" "group:2025-interns@pcioasis.com")

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
  
  for GROUP in "${GROUPS[@]}"; do
    # Check if binding already exists
    if gcloud run services get-iam-policy "$SERVICE" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --flatten="bindings[].members" \
      --filter="bindings.members:$GROUP AND bindings.role:roles/run.invoker" \
      --format="value(bindings.members)" | grep -q "$GROUP"; then
      echo "   ✅ $GROUP already has access"
    else
      echo "   ➕ Adding $GROUP..."
      gcloud run services add-iam-policy-binding "$SERVICE" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --member="$GROUP" \
        --role="roles/run.invoker" || {
        echo "   ❌ Failed to add $GROUP"
      }
    fi
  done
  echo ""
done

echo "✅ Done! IAM bindings updated."
echo ""
echo "💡 To verify, run:"
echo "   ./verify-iam-bindings.sh"

