#!/usr/bin/env bash
# Run lab-specific Playwright tests against production environment (labs.pcioasis.com)
# Tests individual lab functionality: checkout flows, skimmer detection, C2 exfiltration

set -e

echo "🧪 Running LAB-SPECIFIC tests against PRODUCTION environment (labs.pcioasis.com)"
echo "📋 Tests: Individual lab functionality (checkout, skimmer detection, C2 exfiltration)"
echo "⚠️  Note: This requires the production services to be running"
echo ""

# Set test environment
export TEST_ENV=prd

# Determine which lab to test
LAB=${1:-"all"}

case $LAB in
  1|lab1)
    echo "📍 Testing Lab 1: Basic Magecart"
    cd labs/01-basic-magecart/test
    npm test
    ;;
  2|lab2)
    echo "📍 Testing Lab 2: DOM Skimming"
    cd labs/02-dom-skimming/test
    npm test
    ;;
  3|lab3)
    echo "📍 Testing Lab 3: Extension Hijacking"
    cd labs/03-extension-hijacking
    npm test
    ;;
  all)
    echo "📍 Testing all labs"
    echo ""
    echo "▶️  Lab 1: Basic Magecart"
    cd labs/01-basic-magecart/test
    npm test
    cd ../../..

    echo ""
    echo "▶️  Lab 2: DOM Skimming"
    cd labs/02-dom-skimming/test
    npm test
    cd ../../..

    echo ""
    echo "▶️  Lab 3: Extension Hijacking"
    cd labs/03-extension-hijacking
    npm test
    cd ../..
    ;;
  *)
    echo "❌ Invalid lab number. Usage: $0 [1|2|3|all]"
    exit 1
    ;;
esac

echo ""
echo "✅ Tests completed!"
