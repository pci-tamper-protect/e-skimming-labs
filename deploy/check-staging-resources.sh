#!/bin/bash

# Check for existing resources in staging projects
# Staging should be empty - if resources exist, they may need to be cleaned up

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment configuration
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
elif [ -f "$SCRIPT_DIR/.env.stg" ]; then
    source "$SCRIPT_DIR/.env.stg"
fi

LABS_PROJECT="${LABS_PROJECT_ID:-labs-stg}"
HOME_PROJECT="${HOME_PROJECT_ID:-labs-home-stg}"

echo "🔍 Checking for existing resources in staging projects"
echo "====================================================="
echo "Labs Project: $LABS_PROJECT"
echo "Home Project: $HOME_PROJECT"
echo ""

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "⚠️  gcloud not found in PATH. Cannot check resources."
    echo "   Please run these commands manually:"
    echo ""
    echo "   # Check Firestore databases"
    echo "   gcloud firestore databases list --project=$LABS_PROJECT"
    echo "   gcloud firestore databases list --project=$HOME_PROJECT"
    echo ""
    echo "   # Check service accounts"
    echo "   gcloud iam service-accounts list --project=$LABS_PROJECT"
    echo "   gcloud iam service-accounts list --project=$HOME_PROJECT"
    echo ""
    echo "   # Check storage buckets"
    echo "   gsutil ls -p $LABS_PROJECT"
    echo "   gsutil ls -p $HOME_PROJECT"
    echo ""
    exit 0
fi

echo "📊 Checking Firestore databases..."
echo ""

# Check labs project
echo "Labs Project ($LABS_PROJECT):"
if gcloud firestore databases list --project="$LABS_PROJECT" 2>&1 | grep -q "(default)"; then
    echo "  ⚠️  Firestore database exists!"
    echo "     If staging should be empty, delete it:"
    echo "     gcloud firestore databases delete (default) --project=$LABS_PROJECT"
else
    echo "  ✅ No Firestore database found"
fi

# Check home project
echo ""
echo "Home Project ($HOME_PROJECT):"
if gcloud firestore databases list --project="$HOME_PROJECT" 2>&1 | grep -q "(default)"; then
    echo "  ⚠️  Firestore database exists!"
    echo "     If staging should be empty, delete it:"
    echo "     gcloud firestore databases delete (default) --project=$HOME_PROJECT"
else
    echo "  ✅ No Firestore database found"
fi

echo ""
echo "📊 Checking service accounts..."
echo ""

# Check service accounts
LABS_SAS=$(gcloud iam service-accounts list --project="$LABS_PROJECT" --format="value(email)" 2>/dev/null | wc -l | tr -d ' ')
HOME_SAS=$(gcloud iam service-accounts list --project="$HOME_PROJECT" --format="value(email)" 2>/dev/null | wc -l | tr -d ' ')

echo "Labs Project: $LABS_SAS service account(s)"
if [ "$LABS_SAS" -gt 0 ]; then
    echo "  ⚠️  Service accounts exist. List them:"
    echo "     gcloud iam service-accounts list --project=$LABS_PROJECT"
fi

echo "Home Project: $HOME_SAS service account(s)"
if [ "$HOME_SAS" -gt 0 ]; then
    echo "  ⚠️  Service accounts exist. List them:"
    echo "     gcloud iam service-accounts list --project=$HOME_PROJECT"
fi

echo ""
echo "📊 Checking storage buckets..."
echo ""

# Check buckets
LABS_BUCKETS=$(gsutil ls -p "$LABS_PROJECT" 2>/dev/null | wc -l | tr -d ' ')
HOME_BUCKETS=$(gsutil ls -p "$HOME_PROJECT" 2>/dev/null | wc -l | tr -d ' ')

echo "Labs Project: $LABS_BUCKETS bucket(s)"
if [ "$LABS_BUCKETS" -gt 0 ]; then
    echo "  ⚠️  Buckets exist. List them:"
    echo "     gsutil ls -p $LABS_PROJECT"
fi

echo "Home Project: $HOME_BUCKETS bucket(s)"
if [ "$HOME_BUCKETS" -gt 0 ]; then
    echo "  ⚠️  Buckets exist. List them:"
    echo "     gsutil ls -p $HOME_PROJECT"
fi

echo ""
echo "✅ Check complete!"
echo ""
echo "If resources exist and staging should be empty, you may need to:"
echo "1. Delete the Firestore database (if it exists)"
echo "2. Clean up any other resources"
echo "3. Then run terraform apply again"
echo ""


