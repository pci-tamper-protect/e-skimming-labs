#!/bin/bash
# Test relative URL detection locally
# This script runs the home-index-service locally and tests if it detects proxy access

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🧪 Testing relative URL detection locally..."
echo ""

# Check if Go is installed
if ! command -v go &> /dev/null; then
  echo "❌ Error: Go is not installed"
  echo "   Install Go: https://golang.org/dl/"
  exit 1
fi

# Set environment variables for local testing
TEST_PORT=18080  # Use different port to avoid conflicts
export PORT=$TEST_PORT
export ENVIRONMENT=local
export DOMAIN=localhost:$TEST_PORT
export LABS_DOMAIN=localhost:$TEST_PORT
export MAIN_DOMAIN=pcioasis.com
export LABS_PROJECT_ID=labs-stg

echo "📋 Test Configuration:"
echo "   Port: $PORT"
echo "   Environment: $ENVIRONMENT"
echo "   Domain: $DOMAIN"
echo ""

# Build the service
echo "🔨 Building service..."
cd "$SCRIPT_DIR"
go build -o /tmp/home-index-test .

# Start the service in background
echo "🚀 Starting service on port $PORT..."
/tmp/home-index-test &
SERVICE_PID=$!

# Wait for service to start
sleep 2

# Check if service is running
if ! kill -0 $SERVICE_PID 2>/dev/null; then
  echo "❌ Error: Service failed to start"
  exit 1
fi

echo "✅ Service started (PID: $SERVICE_PID)"
echo ""

# Test 1: Direct access (should use absolute URLs)
echo "Test 1: Direct access (localhost:$TEST_PORT) - should use ABSOLUTE URLs"
RESPONSE1=$(curl -s -H "Host: localhost:$TEST_PORT" http://localhost:$TEST_PORT/)
if echo "$RESPONSE1" | grep -q 'href="http://localhost:8080/mitre-attack"'; then
  echo "   ✅ PASS: Uses absolute URL (expected)"
else
  echo "   ❌ FAIL: Expected absolute URL"
  echo "$RESPONSE1" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
fi
echo ""

# Test 2: Proxy access via Host header (should use relative URLs)
echo "Test 2: Proxy access (Host: 127.0.0.1:8081) - should use RELATIVE URLs"
RESPONSE2=$(curl -s -H "Host: 127.0.0.1:8081" http://localhost:$TEST_PORT/)
if echo "$RESPONSE2" | grep -q 'href="/mitre-attack"'; then
  echo "   ✅ PASS: Uses relative URL"
else
  echo "   ❌ FAIL: Expected relative URL"
  echo "$RESPONSE2" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
fi
echo ""

# Test 3: Proxy access via X-Forwarded-For (should use relative URLs)
echo "Test 3: Proxy access (X-Forwarded-For: 127.0.0.1) - should use RELATIVE URLs"
RESPONSE3=$(curl -s -H "X-Forwarded-For: 127.0.0.1" http://localhost:$TEST_PORT/)
if echo "$RESPONSE3" | grep -q 'href="/mitre-attack"'; then
  echo "   ✅ PASS: Uses relative URL (detected via X-Forwarded-For)"
else
  echo "   ❌ FAIL: Expected relative URL"
  echo "$RESPONSE3" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
fi
echo ""

# Test 4: Proxy access via X-Forwarded-Host (should use relative URLs)
echo "Test 4: Proxy access (X-Forwarded-Host: 127.0.0.1:8081) - should use RELATIVE URLs"
RESPONSE4=$(curl -s -H "X-Forwarded-Host: 127.0.0.1:8081" http://localhost:$TEST_PORT/)
if echo "$RESPONSE4" | grep -q 'href="/mitre-attack"'; then
  echo "   ✅ PASS: Uses relative URL (detected via X-Forwarded-Host)"
else
  echo "   ❌ FAIL: Expected relative URL"
  echo "$RESPONSE4" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
fi
echo ""

# Test 5: Combined headers (should use relative URLs)
echo "Test 5: Proxy access (Host + X-Forwarded-For) - should use RELATIVE URLs"
RESPONSE5=$(curl -s -H "Host: home-index-stg-xxxxx-uc.a.run.app" -H "X-Forwarded-For: 127.0.0.1" http://localhost:$TEST_PORT/)
if echo "$RESPONSE5" | grep -q 'href="/mitre-attack"'; then
  echo "   ✅ PASS: Uses relative URL (detected via X-Forwarded-For even with Cloud Run Host)"
else
  echo "   ❌ FAIL: Expected relative URL"
  echo "$RESPONSE5" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
fi
echo ""

# Show actual URLs found
echo "📊 Summary of detected URLs:"
echo ""
echo "Test 1 (Direct):"
echo "$RESPONSE1" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
echo ""
echo "Test 2 (Host: 127.0.0.1:8081):"
echo "$RESPONSE2" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
echo ""
echo "Test 3 (X-Forwarded-For: 127.0.0.1):"
echo "$RESPONSE3" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
echo ""
echo "Test 4 (X-Forwarded-Host: 127.0.0.1:8081):"
echo "$RESPONSE4" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
echo ""
echo "Test 5 (Combined):"
echo "$RESPONSE5" | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1
echo ""

# Cleanup
echo "🧹 Cleaning up..."
kill $SERVICE_PID 2>/dev/null || true
rm -f /tmp/home-index-test
echo "✅ Test complete!"
