#!/bin/bash
# Protect stg branch from deletion
# This script sets up branch protection for the stg branch to prevent accidental deletion

set -e

REPO_OWNER="${REPO_OWNER:-pci-tamper-protect}"
REPO_NAME="${REPO_NAME:-e-skimming-labs}"

echo "🔒 Protecting stg branch from deletion..."

# Create branch protection configuration
PROTECTION_JSON=$(cat <<EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
)

# Apply branch protection
echo "$PROTECTION_JSON" | gh api "repos/${REPO_OWNER}/${REPO_NAME}/branches/stg/protection" \
  --method PUT \
  --input -

echo "✅ stg branch is now protected from deletion"
echo ""
echo "Protection settings:"
echo "  - Deletion: DISABLED (branch cannot be deleted)"
echo "  - Force pushes: DISABLED"
echo "  - Direct pushes: ALLOWED (can be changed via Rulesets)"

