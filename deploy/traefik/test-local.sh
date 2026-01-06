#!/bin/bash
# Local testing script for Traefik configuration
# This script builds and runs Traefik locally to test ForwardAuth middlewares

set -e

echo "🧪 Traefik Local Test Environment"
echo "=================================="
echo ""

# Clean up previous test
echo "🧹 Cleaning up previous test containers..."
docker-compose -f docker-compose.test.yml down -v 2>/dev/null || true

# Build fresh image
echo "🔨 Building Traefik test image..."
docker-compose -f docker-compose.test.yml build --no-cache

# Start services
echo "🚀 Starting Traefik and mock backend..."
docker-compose -f docker-compose.test.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 5

# Show logs
echo ""
echo "📋 Traefik startup logs:"
echo "========================"
docker-compose -f docker-compose.test.yml logs traefik-test | grep -E "🔍|ForwardAuth|auth-check|Creating middleware" || echo "  (No ForwardAuth logs found)"

echo ""
echo "📊 Checking loaded middlewares..."
echo "================================="
docker-compose -f docker-compose.test.yml exec -T traefik-test \
  wget -q -O- http://localhost:8080/api/http/middlewares | \
  python3 -m json.tool | \
  grep -E '"name":|"type":' | \
  head -30

echo ""
echo "🔍 Checking generated config file..."
echo "====================================="
docker-compose -f docker-compose.test.yml exec -T traefik-test \
  cat /etc/traefik/dynamic/cloudrun-services.yml | \
  grep -A 10 "auth-check:" || echo "  ⚠️  No ForwardAuth middlewares in generated config!"

echo ""
echo "🧪 Testing ForwardAuth middleware..."
echo "====================================="
echo "Attempting to access /lab2 (should trigger ForwardAuth check)..."
curl -v http://localhost:8080/lab2 2>&1 | grep -E "HTTP/|< X-User-" || true

echo ""
echo "📝 Useful commands:"
echo "  View all logs:       docker-compose -f docker-compose.test.yml logs -f"
echo "  View Traefik logs:   docker-compose -f docker-compose.test.yml logs -f traefik-test"
echo "  View backend logs:   docker-compose -f docker-compose.test.yml logs -f mock-backend"
echo "  Check middlewares:   curl http://localhost:8080/api/http/middlewares | jq"
echo "  Stop services:       docker-compose -f docker-compose.test.yml down"
echo ""
echo "🌐 Access points:"
echo "  Traefik HTTP:        http://localhost:8080"
echo "  Traefik Dashboard:   http://localhost:8081/dashboard/"
echo "  Test /lab2:          http://localhost:8080/lab2"
echo ""
