#!/bin/bash
# Check what headers are being sent through the proxy
# This helps debug why proxy detection might not be working

echo "🔍 Checking headers sent through proxy..."
echo ""

# Test 1: Check what Host header is sent
echo "Test 1: Host header"
curl -s -v http://127.0.0.1:8081/ 2>&1 | grep -i "> host:"

# Test 2: Check X-Forwarded-For
echo ""
echo "Test 2: X-Forwarded-For header"
curl -s -v http://127.0.0.1:8081/ 2>&1 | grep -i "x-forwarded-for"

# Test 3: Check X-Forwarded-Host
echo ""
echo "Test 3: X-Forwarded-Host header"
curl -s -v http://127.0.0.1:8081/ 2>&1 | grep -i "x-forwarded-host"

# Test 4: Check all forwarded headers
echo ""
echo "Test 4: All X-Forwarded-* headers"
curl -s -v http://127.0.0.1:8081/ 2>&1 | grep -i "x-forwarded"

# Test 5: Check what the actual HTML contains
echo ""
echo "Test 5: MITRE URL in HTML"
curl -s http://127.0.0.1:8081/ | grep -o 'href="[^"]*mitre-attack[^"]*"' | head -1

echo ""
echo "✅ Header check complete"
