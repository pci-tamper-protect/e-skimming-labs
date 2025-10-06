#!/bin/bash

# E-Skimming Lab - Automated Checkout Testing
# FOR DEVELOPMENT USE ONLY

set -e

echo "🧪 E-Skimming Lab - Automated Testing"
echo "====================================="

# Check if containers are running
echo "🔍 Checking if lab containers are running..."

if ! curl -s http://localhost:8080 > /dev/null; then
    echo "❌ Vulnerable site not running on http://localhost:8080"
    echo "   Run: docker-compose up -d"
    exit 1
fi

if ! curl -s http://localhost:3000/health > /dev/null; then
    echo "❌ C2 server not running on http://localhost:3000"
    echo "   Run: docker-compose up -d"
    exit 1
fi

echo "✅ Lab containers are running"

# Install dependencies if needed
if [ ! -d "test/node_modules" ]; then
    echo "📦 Installing test dependencies..."
    cd test
    npm install
    cd ..
fi

# Run the tests
echo "🚀 Running automated checkout tests..."
echo ""

cd test

echo "Test 1: Basic checkout flow with skimmer detection"
echo "================================================"
npx playwright test tests/checkout.spec.js::checkout --reporter=line

echo ""
echo "📊 Test Results Summary"
echo "====================="

# Check C2 server for captured data
echo "🔍 Checking C2 server for captured data..."
STOLEN_COUNT=$(curl -s http://localhost:3000/stolen | grep -o "Record #" | wc -l | tr -d ' ')

if [ "$STOLEN_COUNT" -gt 0 ]; then
    echo "✅ C2 Server captured $STOLEN_COUNT records"
    echo "   View at: http://localhost:3000/stolen"
else
    echo "⚠️  No data found in C2 server"
    echo "   Check server logs: docker logs attacker-c2"
fi

echo ""
echo "🎯 Manual verification steps:"
echo "1. Check browser console logs in test output above"
echo "2. Visit http://localhost:3000/stolen to see captured data"
echo "3. Check C2 server logs: docker logs attacker-c2"
echo ""

cd ..