#!/bin/bash
# Verify IAM bindings for home-index-stg service
# This script checks if the required group IAM bindings are in place

set -euo pipefail

PROJECT_ID="${HOME_PROJECT_ID:-labs-home-stg}"
SERVICE_NAME="home-index-stg"
REGION="us-central1"

echo "🔍 Checking IAM bindings for $SERVICE_NAME in project $PROJECT_ID"
echo ""

# Check if service exists
if ! gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" &>/dev/null; then
  echo "❌ Service $SERVICE_NAME does not exist in project $PROJECT_ID"
  exit 1
fi

echo "✅ Service exists"
echo ""

# Get IAM policy
echo "📋 Current IAM bindings:"
gcloud run services get-iam-policy "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="table(bindings.role,bindings.members)" || {
  echo "❌ Failed to get IAM policy"
  exit 1
}

echo ""
echo "🔍 Checking for required groups..."

# Check for core-eng group
if gcloud run services get-iam-policy "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:group:core-eng@pcioasis.com AND bindings.role:roles/run.invoker" \
  --format="value(bindings.members)" | grep -q "group:core-eng@pcioasis.com"; then
  echo "✅ core-eng@pcioasis.com has roles/run.invoker"
else
  echo "❌ core-eng@pcioasis.com does NOT have roles/run.invoker"
fi

# Check for 2025-interns group
if gcloud run services get-iam-policy "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:group:2025-interns@pcioasis.com AND bindings.role:roles/run.invoker" \
  --format="value(bindings.members)" | grep -q "group:2025-interns@pcioasis.com"; then
  echo "✅ 2025-interns@pcioasis.com has roles/run.invoker"
else
  echo "❌ 2025-interns@pcioasis.com does NOT have roles/run.invoker"
fi

echo ""
echo "💡 To fix missing bindings, run Terraform:"
echo "   cd deploy/terraform-home"
echo "   terraform init -backend-config=backend-stg.conf"
echo "   terraform apply -var=\"environment=stg\""
echo ""
echo "   Or manually add bindings:"
echo "   gcloud run services add-iam-policy-binding $SERVICE_NAME \\"
echo "     --region=$REGION \\"
echo "     --project=$PROJECT_ID \\"
echo "     --member=\"group:core-eng@pcioasis.com\" \\"
echo "     --role=\"roles/run.invoker\""
echo ""
echo "   gcloud run services add-iam-policy-binding $SERVICE_NAME \\"
echo "     --region=$REGION \\"
echo "     --project=$PROJECT_ID \\"
echo "     --member=\"group:2025-interns@pcioasis.com\" \\"
echo "     --role=\"roles/run.invoker\""

