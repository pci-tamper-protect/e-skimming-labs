#!/bin/bash
# Setup branch protection with CODEOWNERS and team-based approvals
# - stg: Requires CODEOWNERS approval (engineering-core team)
# - main: Requires team approval (engineering-core), allows bypass for team members

set -e

REPO_OWNER="${REPO_OWNER:-pci-tamper-protect}"
REPO_NAME="${REPO_NAME:-e-skimming-labs}"
TEAM_SLUG="${TEAM_SLUG:-engineering-core}"

echo "🔒 Setting up branch protection with CODEOWNERS..."

# Get team ID
TEAM_ID=$(gh api orgs/$REPO_OWNER/teams/$TEAM_SLUG --jq '.id')
echo "Team ID for $TEAM_SLUG: $TEAM_ID"

# Configure stg branch: Require CODEOWNERS approval
echo ""
echo "📋 Configuring stg branch protection (CODEOWNERS required)..."
cat > /tmp/stg-protection.json << EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": true,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

gh api repos/$REPO_OWNER/$REPO_NAME/branches/stg/protection \
  --method PUT \
  --input /tmp/stg-protection.json > /dev/null

echo "✅ stg branch protection configured (CODEOWNERS required)"

# Configure main branch: Require team approval (not CODEOWNERS), allow bypass
echo ""
echo "📋 Configuring main branch protection (team approval, bypass allowed)..."
cat > /tmp/main-protection.json << EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

gh api repos/$REPO_OWNER/$REPO_NAME/branches/main/protection \
  --method PUT \
  --input /tmp/main-protection.json > /dev/null

echo "✅ main branch protection configured (team approval, no CODEOWNERS)"

# Update or create ruleset for main with bypass_actors
echo ""
echo "📋 Configuring main branch ruleset with bypass for $TEAM_SLUG..."
MAIN_RULESET_ID=$(gh api repos/$REPO_OWNER/$REPO_NAME/rulesets 2>&1 | jq -r '.[] | select(.conditions.ref_name.include[]? == "refs/heads/main") | .id' | head -1)

if [ -n "$MAIN_RULESET_ID" ] && [ "$MAIN_RULESET_ID" != "null" ]; then
  echo "Updating existing ruleset ID: $MAIN_RULESET_ID"
  CURRENT_RULESET=$(gh api repos/$REPO_OWNER/$REPO_NAME/rulesets/$MAIN_RULESET_ID)
  UPDATED_RULESET=$(echo "$CURRENT_RULESET" | jq ".bypass_actors = [{\"actor_type\": \"Team\", \"actor_id\": $TEAM_ID}]")
  echo "$UPDATED_RULESET" > /tmp/updated-ruleset.json
  gh api repos/$REPO_OWNER/$REPO_NAME/rulesets/$MAIN_RULESET_ID \
    --method PUT \
    --input /tmp/updated-ruleset.json > /dev/null
  echo "✅ Updated existing ruleset with bypass for $TEAM_SLUG"
else
  echo "Creating new ruleset for main branch..."
  cat > /tmp/main-ruleset.json << EOF
{
  "name": "main-only-merge-from-stg",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_type": "Team",
      "actor_id": $TEAM_ID
    }
  ]
}
EOF
  gh api repos/$REPO_OWNER/$REPO_NAME/rulesets \
    --method POST \
    --input /tmp/main-ruleset.json > /dev/null
  echo "✅ Created new ruleset with bypass for $TEAM_SLUG"
fi

echo ""
echo "✅ Branch protection setup complete!"
echo ""
echo "Summary:"
echo "  - stg: Requires CODEOWNERS approval (engineering-core team)"
echo "  - main: Requires team approval (engineering-core), bypass allowed for team members"
echo ""
echo "Note: CODEOWNERS file must exist at .github/CODEOWNERS"

