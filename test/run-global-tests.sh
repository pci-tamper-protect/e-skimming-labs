#!/bin/bash
# Run only global navigation tests (test/e2e/)
#
# Usage:
#   ./test/run-global-tests.sh [local|prd]
#
# Examples:
#   ./test/run-global-tests.sh local    # Test against localhost
#   ./test/run-global-tests.sh prd      # Test against production
#   ./test/run-global-tests.sh          # Defaults to local

set -e

ENV=${1:-local}

echo "🧪 Running global navigation tests against ${ENV} environment"
echo ""

# Set test environment
export TEST_ENV=$ENV

# Run tests from test directory
cd test
npm test

echo ""
echo "✅ Global tests completed!"

