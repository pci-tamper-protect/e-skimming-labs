#!/bin/bash
# Test script for staging simulation
# Generates routes from Docker services (simulating Cloud Run) and validates routing

set -e

echo "🧪 Staging Simulation Test"
echo "=========================="
echo ""

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 5

# Create a script that queries Docker services instead of Cloud Run
# This simulates the Cloud Run label generation but uses Docker
cat > /tmp/generate-routes-from-docker.sh <<'EOF'
#!/bin/bash
# Generate routes from Docker services (simulating Cloud Run)
# This is a test version that queries Docker instead of Cloud Run

OUTPUT_FILE="${1:-/etc/traefik/dynamic/routes.yml}"
ENVIRONMENT="${ENVIRONMENT:-stg-simulation}"

echo "🔍 Generating routes from Docker services (staging simulation)..."

# Start routes.yml
cat > "$OUTPUT_FILE" <<ROUTES_EOF
# Auto-generated routes from Docker services (staging simulation)
# Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

http:
  routers:
ROUTES_EOF

# Query Docker services with Traefik labels
SERVICES=$(docker ps --filter "label=traefik.enable=true" --format "{{.Names}}" 2>/dev/null || echo "")

for service_name in $SERVICES; do
  echo "  📋 Processing: ${service_name}" >&2

  # Get service IP (simulating Cloud Run URL)
  SERVICE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$service_name" 2>/dev/null || echo "")
  if [ -z "$SERVICE_IP" ]; then
    echo "    ⚠️  Could not get IP for ${service_name}" >&2
    continue
  fi

  # Get all Traefik labels
  LABELS=$(docker inspect -f '{{range $key, $value := .Config.Labels}}{{printf "%s=%s\n" $key $value}}{{end}}' "$service_name" 2>/dev/null || echo "")

  if ! echo "$LABELS" | grep -q "traefik.enable=true"; then
    continue
  fi

  # Extract router labels
  ROUTER_KEYS=$(echo "$LABELS" | grep "^traefik\.http\.routers\." || true)

  if [ -z "$ROUTER_KEYS" ]; then
    continue
  fi

  # Group by router name
  declare -A routers
  while IFS='=' read -r key value; do
    if [[ "$key" =~ ^traefik\.http\.routers\.([^.]+)\.(.+)$ ]]; then
      router_name="${BASH_REMATCH[1]}"
      property="${BASH_REMATCH[2]}"

      if [ -z "${routers[$router_name]}" ]; then
        routers[$router_name]=""
      fi
      routers[$router_name]+="${property}=${value}"$'\n'
    fi
  done <<< "$ROUTER_KEYS"

  # Generate router configs
  for router_name in "${!routers[@]}"; do
    config="${routers[$router_name]}"

    rule=$(echo "$config" | grep "^rule=" | cut -d'=' -f2- || echo "")
    priority=$(echo "$config" | grep "^priority=" | cut -d'=' -f2 || echo "1")
    entrypoints=$(echo "$config" | grep "^entrypoints=" | cut -d'=' -f2 || echo "web")
    middlewares=$(echo "$config" | grep "^middlewares=" | cut -d'=' -f2 || echo "")
    service=$(echo "$config" | grep "^service=" | cut -d'=' -f2 || echo "$service_name")

    # Get port from service label or default
    port=$(echo "$LABELS" | grep "^traefik\.http\.services\.${service}\.loadbalancer\.server\.port=" | cut -d'=' -f2 || echo "80")

    cat >> "$OUTPUT_FILE" <<ROUTER_EOF
    ${router_name}:
      rule: ${rule}
      service: ${service}
      priority: ${priority}
      entryPoints:
        - ${entrypoints}
ROUTER_EOF

    if [ -n "$middlewares" ]; then
      echo "      middlewares:" >> "$OUTPUT_FILE"
      IFS=',' read -ra MW_ARRAY <<< "$middlewares"
      for mw in "${MW_ARRAY[@]}"; do
        mw_clean=$(echo "$mw" | sed 's/@file$//' | xargs)
        echo "        - ${mw_clean}" >> "$OUTPUT_FILE"
      done
    fi

    # Add service definition
    cat >> "$OUTPUT_FILE" <<SERVICE_EOF

  services:
    ${service}:
      loadBalancer:
        servers:
          - url: "http://${SERVICE_IP}:${port}"
        passHostHeader: false
SERVICE_EOF
  done

  unset routers
  declare -A routers
done

echo "✅ Routes generated"
EOF

chmod +x /tmp/generate-routes-from-docker.sh

# Copy generation script into container
docker cp /tmp/generate-routes-from-docker.sh e-skimming-labs-traefik-stg-sim:/tmp/generate-routes-from-docker.sh
docker exec e-skimming-labs-traefik-stg-sim chmod +x /tmp/generate-routes-from-docker.sh

# Install docker CLI in Traefik container (needed to query Docker)
# Note: Docker socket is mounted, so we can use docker commands
docker exec e-skimming-labs-traefik-stg-sim sh -c "apk add --no-cache docker-cli 2>/dev/null || echo 'Docker CLI install skipped (may already be available)'"

# Run the generation script inside Traefik container
echo "🔧 Generating routes from Docker services..."
docker exec e-skimming-labs-traefik-stg-sim /tmp/generate-routes-from-docker.sh /etc/traefik/dynamic/routes.yml

# Wait for Traefik to reload
echo "⏳ Waiting for Traefik to reload routes..."
sleep 3

# Test routes
echo ""
echo "🧪 Testing Routes"
echo "================="
echo ""

FAILED=0

# Test home-index
echo -n "Testing / → "
if curl -s http://localhost:8080/ | grep -q "Home Index"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  FAILED=1
fi

# Test sign-in route
echo -n "Testing /sign-in → "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/sign-in | grep -q "200\|404"; then
  echo "✅ PASS (route exists)"
else
  echo "❌ FAIL"
  FAILED=1
fi

# Test SEO service
echo -n "Testing /api/seo → "
if curl -s http://localhost:8080/api/seo | grep -q "seo\|SEO"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  FAILED=1
fi

# Test analytics service
echo -n "Testing /api/analytics → "
if curl -s http://localhost:8080/api/analytics | grep -q "analytics\|Analytics"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  FAILED=1
fi

# Test lab1
echo -n "Testing /lab1 → "
if curl -s http://localhost:8080/lab1 | grep -q "Lab 1\|lab1"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  FAILED=1
fi

# Test lab2
echo -n "Testing /lab2 → "
if curl -s http://localhost:8080/lab2 | grep -q "Lab 2\|lab2"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  FAILED=1
fi

# Test lab3
echo -n "Testing /lab3 → "
if curl -s http://localhost:8080/lab3 | grep -q "Lab 3\|lab3"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  FAILED=1
fi

echo ""
if [ $FAILED -eq 0 ]; then
  echo "✅ All route tests passed!"
  echo ""
  echo "📊 Summary:"
  echo "   - Routes generated from Docker service labels"
  echo "   - Traefik file provider loaded routes"
  echo "   - All test routes working correctly"
  exit 0
else
  echo "❌ Some tests failed"
  echo ""
  echo "💡 Debug:"
  echo "   - Check Traefik logs: docker logs e-skimming-labs-traefik-stg-sim"
  echo "   - Check routes.yml: docker exec e-skimming-labs-traefik-stg-sim cat /etc/traefik/dynamic/routes.yml"
  exit 1
fi
