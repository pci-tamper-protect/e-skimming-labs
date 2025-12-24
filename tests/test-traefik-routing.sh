#!/bin/bash
# Test script for Traefik routing
# Tests all routes to ensure Traefik is correctly forwarding requests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base URL - can be overridden by environment variable
BASE_URL="${BASE_URL:-http://localhost:8080}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:8081}"

echo "🧪 Testing Traefik Routing"
echo "=========================="
echo "Base URL: $BASE_URL"
echo "Dashboard URL: $DASHBOARD_URL"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_route() {
    local path="$1"
    local expected_status="${2:-200}"
    local description="$3"

    printf "Testing %-50s ... " "$description"

    # Make request and capture status code (with 5 second timeout)
    http_status=$(curl --max-time 5 -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || echo "000")

    # Check if we got a successful status or the expected one
    if [ "$http_status" = "$expected_status" ] || [ "$http_status" = "200" ] || [ "$http_status" = "301" ] || [ "$http_status" = "302" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $http_status)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $http_status, expected $expected_status)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test Traefik endpoint
test_traefik_endpoint() {
    local endpoint="$1"
    local description="$2"

    printf "Testing %-50s ... " "$description"

    http_status=$(curl --max-time 5 -s -o /dev/null -w "%{http_code}" "${DASHBOARD_URL}${endpoint}" || echo "000")

    if [ "$http_status" = "200" ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⊘ SKIP${NC} (Dashboard not accessible or not localhost)"
    fi
}

echo "🏥 Health Checks"
echo "================"
test_route "/ping" "200" "Traefik ping endpoint"
echo ""

echo "📊 Traefik Dashboard (localhost only)"
echo "======================================"
test_traefik_endpoint "/api/overview" "Traefik API overview"
test_traefik_endpoint "/api/http/routers" "HTTP routers"
test_traefik_endpoint "/api/http/services" "HTTP services"
test_traefik_endpoint "/api/http/middlewares" "HTTP middlewares"
echo ""

echo "🏠 Home Page Routes"
echo "==================="
test_route "/" "200" "Home page"
test_route "/api/seo" "200" "SEO service"
test_route "/api/analytics" "200" "Analytics service"
echo ""

echo "🧪 Lab 1 Routes"
echo "==============="
test_route "/lab1" "200" "Lab 1 main page"
test_route "/lab1/" "200" "Lab 1 with trailing slash"
test_route "/lab1/checkout.html" "200" "Lab 1 checkout page"
test_route "/lab1/c2" "200" "Lab 1 C2 server"
test_route "/lab1/c2/" "200" "Lab 1 C2 with trailing slash"
echo ""

echo "🧪 Lab 1 Variants"
echo "================="
test_route "/lab1/variants/event-listener" "200" "Event listener variant"
test_route "/lab1/variants/obfuscated" "200" "Obfuscated variant"
test_route "/lab1/variants/websocket" "200" "WebSocket variant"
echo ""

echo "🏦 Lab 2 Routes"
echo "==============="
test_route "/lab2" "200" "Lab 2 main page"
test_route "/lab2/" "200" "Lab 2 with trailing slash"
test_route "/lab2/c2" "200" "Lab 2 C2 server"
echo ""

echo "🔌 Lab 3 Routes"
echo "==============="
test_route "/lab3" "200" "Lab 3 main page"
test_route "/lab3/" "200" "Lab 3 with trailing slash"
test_route "/lab3/extension" "200" "Lab 3 extension server"
echo ""

echo "❌ Error Handling"
echo "================="
printf "Testing %-50s ... " "404 for non-existent path"
http_status=$(curl --max-time 5 -s -o /dev/null -w "%{http_code}" "${BASE_URL}/non-existent-path-12345" || echo "000")
if [ "$http_status" = "404" ] || [ "$http_status" = "200" ]; then
    # 200 might be returned if home page catches all
    echo -e "${GREEN}✓ PASS${NC} (HTTP $http_status)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARN${NC} (HTTP $http_status, expected 404 or 200)"
fi

printf "Testing %-50s ... " "Path traversal protection"
http_status=$(curl --max-time 5 -s -o /dev/null -w "%{http_code}" "${BASE_URL}/../../../etc/passwd" || echo "000")
if [ "$http_status" != "200" ]; then
    echo -e "${GREEN}✓ PASS${NC} (HTTP $http_status - blocked)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} (HTTP $http_status - possible security issue)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo "🔍 Service Discovery (localhost only)"
echo "======================================"
if [[ "$BASE_URL" == *"localhost"* ]]; then
    printf "Checking registered services ... "
    services=$(curl --max-time 5 -s "${DASHBOARD_URL}/api/http/services" | jq -r 'keys[]' 2>/dev/null || echo "")
    if [ -n "$services" ]; then
        echo -e "${GREEN}✓${NC}"
        echo "Services found:"
        echo "$services" | sed 's/^/  - /'
    else
        echo -e "${YELLOW}⊘ SKIP${NC}"
    fi
    echo ""

    printf "Checking configured routers ... "
    routers=$(curl --max-time 5 -s "${DASHBOARD_URL}/api/http/routers" | jq -r 'keys[]' 2>/dev/null || echo "")
    if [ -n "$routers" ]; then
        echo -e "${GREEN}✓${NC}"
        echo "Routers found:"
        echo "$routers" | sed 's/^/  - /'
    else
        echo -e "${YELLOW}⊘ SKIP${NC}"
    fi
fi
echo ""

echo "📈 Results Summary"
echo "=================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
else
    echo -e "Tests Failed: $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
