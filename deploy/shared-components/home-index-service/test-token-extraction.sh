#!/bin/bash
# Test script for token extraction debugging
# Usage: ./test-token-extraction.sh [TOKEN]

set -e

TOKEN="${1:-}"

if [ -z "$TOKEN" ]; then
    echo "Usage: $0 <TOKEN>"
    echo ""
    echo "To get your token from browser console:"
    echo "  sessionStorage.getItem('firebase_token') || document.cookie.split('; ').find(row => row.startsWith('firebase_token='))?.split('=')[1]"
    exit 1
fi

BASE_URL="http://127.0.0.1:8080"

echo "=== Testing Token Extraction ==="
echo "Token prefix: ${TOKEN:0:20}..."
echo ""

echo "=== Test 1: Authorization Bearer Token ==="
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/auth/user")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')
echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

echo "=== Test 2: Cookie Header ==="
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -H "Cookie: firebase_token=$TOKEN" \
  "$BASE_URL/api/auth/user")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')
echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

echo "=== Test 3: Query Parameter ==="
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  "$BASE_URL/api/auth/user?token=$TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')
echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

echo "=== Test 4: ForwardAuth Check (via Traefik) ==="
echo "Note: This requires the route to be protected by ForwardAuth"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -H "Cookie: firebase_token=$TOKEN" \
  "$BASE_URL/lab1/")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ ForwardAuth passed - got 200 OK"
elif [ "$HTTP_CODE" = "302" ]; then
    LOCATION=$(curl -s -I -H "Cookie: firebase_token=$TOKEN" "$BASE_URL/lab1/" | grep -i location | cut -d' ' -f2 | tr -d '\r')
    echo "❌ ForwardAuth failed - redirected to: $LOCATION"
else
    echo "HTTP Status: $HTTP_CODE"
fi
echo ""

echo "=== Summary ==="
echo "If all tests return 401 or redirect to sign-in, the token is invalid or expired."
echo "If Test 2 (Cookie) fails but Test 1 (Authorization) works, there's a cookie parsing issue."
echo "If Test 4 (ForwardAuth) fails, check Traefik ForwardAuth configuration."

