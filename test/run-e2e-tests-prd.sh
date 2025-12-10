#!/bin/bash
# Run Playwright e2e tests against production environment (labs.pcioasis.com)

set -e

echo "🧪 Running E2E tests against PRODUCTION environment (labs.pcioasis.com)"
echo "⚠️  Note: This requires the production services to be running"
echo ""

# Set test environment
export TEST_ENV=prd

# Change to test directory
cd "$(dirname "$0")"

echo "📍 Testing against: https://labs.pcioasis.com"
echo ""

# Run the e2e tests
npm test

echo ""
echo "✅ E2E tests completed!"
