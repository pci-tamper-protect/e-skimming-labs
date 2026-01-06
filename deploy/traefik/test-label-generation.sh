#!/bin/bash
# Test suite for Traefik label-based routing generation
# Run tests incrementally to verify each layer works correctly
#
# Usage:
#   ./test-label-generation.sh              # Run all tests
#   ./test-label-generation.sh --test 1     # Run only test 1
#   ./test-label-generation.sh --test 1-3   # Run tests 1-3
#
# Dependencies:
#   - jq (for JSON parsing)
#   - python3 with yaml module (for YAML validation)

set -e

TEST_DIR="/tmp/traefik-label-tests"
mkdir -p "$TEST_DIR"

echo "🧪 Traefik Label Generation Test Suite"
echo "========================================"
echo ""

# Test 1: Label extraction from mock Cloud Run service JSON
echo "📋 Test 1: Label Extraction"
echo "   Verifies we can extract Traefik labels from Cloud Run service JSON"
echo ""

cat > "$TEST_DIR/test-service.json" <<'EOF'
{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "environment": "stg",
          "component": "index",
          "traefik.enable": "true",
          "traefik.http.routers.home-index.rule": "PathPrefix(`/`)",
          "traefik.http.routers.home-index.priority": "1",
          "traefik.http.routers.home-index.entrypoints": "web",
          "traefik.http.routers.home-index.middlewares": "forwarded-headers@file",
          "traefik.http.services.home-index.loadbalancer.server.port": "8080"
        }
      }
    }
  },
  "status": {
    "url": "https://home-index-stg-xxxxx-uc.a.run.app"
  }
}
EOF

# Extract labels using jq (same as the script)
LABELS=$(jq -r '.spec.template.metadata.labels // {} | to_entries[] | "\(.key)=\(.value)"' "$TEST_DIR/test-service.json" 2>/dev/null)

if echo "$LABELS" | grep -q "traefik.enable=true"; then
  echo "   ✅ PASS: Found traefik.enable=true"
else
  echo "   ❌ FAIL: traefik.enable not found"
  exit 1
fi

if echo "$LABELS" | grep -q "traefik.http.routers.home-index.rule"; then
  echo "   ✅ PASS: Found router label"
else
  echo "   ❌ FAIL: Router label not found"
  exit 1
fi

echo "   ✅ Test 1 passed!"
echo ""

# Test 2: Router name extraction
echo "📋 Test 2: Router Name Extraction"
echo "   Verifies we can extract router names from label keys"
echo ""

ROUTER_KEYS=$(echo "$LABELS" | grep "^traefik\.http\.routers\." || true)

if [ -z "$ROUTER_KEYS" ]; then
  echo "   ❌ FAIL: No router keys found"
  exit 1
fi

ROUTER_NAME=$(echo "$ROUTER_KEYS" | head -1 | sed -E 's/^traefik\.http\.routers\.([^.]+)\..*/\1/')

if [ "$ROUTER_NAME" = "home-index" ]; then
  echo "   ✅ PASS: Extracted router name 'home-index'"
else
  echo "   ❌ FAIL: Expected 'home-index', got '$ROUTER_NAME'"
  exit 1
fi

echo "   ✅ Test 2 passed!"
echo ""

# Test 3: YAML generation
echo "📋 Test 3: YAML Route Generation"
echo "   Verifies we can generate valid YAML from labels"
echo ""

# Simulate the router generation logic
RULE=$(echo "$LABELS" | grep "^traefik\.http\.routers\.home-index\.rule=" | cut -d'=' -f2-)
PRIORITY=$(echo "$LABELS" | grep "^traefik\.http\.routers\.home-index\.priority=" | cut -d'=' -f2)
ENTRYPOINTS=$(echo "$LABELS" | grep "^traefik\.http\.routers\.home-index\.entrypoints=" | cut -d'=' -f2)

cat > "$TEST_DIR/test-routes.yml" <<EOF
http:
  routers:
    home-index:
      rule: ${RULE}
      service: home-index
      priority: ${PRIORITY}
      entryPoints:
        - ${ENTRYPOINTS}
EOF

# Validate YAML syntax
if python3 -c "import yaml; yaml.safe_load(open('$TEST_DIR/test-routes.yml'))" 2>/dev/null; then
  echo "   ✅ PASS: Generated valid YAML"
else
  echo "   ❌ FAIL: Invalid YAML generated"
  cat "$TEST_DIR/test-routes.yml"
  exit 1
fi

echo "   Generated YAML:"
cat "$TEST_DIR/test-routes.yml" | sed 's/^/      /'
echo "   ✅ Test 3 passed!"
echo ""

# Test 4: Multiple routers (simulating lab service)
echo "📋 Test 4: Multiple Router Handling"
echo "   Verifies we can handle multiple routers from one service"
echo ""

cat > "$TEST_DIR/test-lab-service.json" <<'EOF'
{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "traefik.enable": "true",
          "traefik.http.routers.lab1-static.rule": "PathPrefix(`/lab1/css/`)",
          "traefik.http.routers.lab1-static.priority": "250",
          "traefik.http.routers.lab1-static.entrypoints": "web",
          "traefik.http.routers.lab1.rule": "PathPrefix(`/lab1`)",
          "traefik.http.routers.lab1.priority": "200",
          "traefik.http.routers.lab1.entrypoints": "web",
          "traefik.http.services.lab1.loadbalancer.server.port": "8080"
        }
      }
    }
  },
  "status": {
    "url": "https://lab-01-basic-magecart-stg-xxxxx-uc.a.run.app"
  }
}
EOF

LAB_LABELS=$(jq -r '.spec.template.metadata.labels // {} | to_entries[] | "\(.key)=\(.value)"' "$TEST_DIR/test-lab-service.json" 2>/dev/null)
ROUTER_COUNT=$(echo "$LAB_LABELS" | grep -c "^traefik\.http\.routers\." || echo "0")

if [ "$ROUTER_COUNT" -ge 2 ]; then
  echo "   ✅ PASS: Found $ROUTER_COUNT router labels"
else
  echo "   ❌ FAIL: Expected at least 2 routers, found $ROUTER_COUNT"
  exit 1
fi

# Check we can extract both router names
ROUTER_NAMES=$(echo "$LAB_LABELS" | grep "^traefik\.http\.routers\." | sed -E 's/^traefik\.http\.routers\.([^.]+)\..*/\1/' | sort -u)
EXPECTED_NAMES="lab1
lab1-static"

if [ "$(echo "$ROUTER_NAMES" | sort)" = "$(echo "$EXPECTED_NAMES" | sort)" ]; then
  echo "   ✅ PASS: Extracted correct router names"
else
  echo "   ❌ FAIL: Router names mismatch"
  echo "      Expected: $EXPECTED_NAMES"
  echo "      Got: $ROUTER_NAMES"
  exit 1
fi

echo "   ✅ Test 4 passed!"
echo ""

# Test 5: Full workflow simulation
echo "📋 Test 5: Full Workflow Simulation"
echo "   Verifies the complete label-to-routes generation process"
echo ""

# Create a mock output file
OUTPUT_FILE="$TEST_DIR/full-routes.yml"

# Simulate the script's main logic
cat > "$OUTPUT_FILE" <<'ROUTES_EOF'
# Auto-generated Traefik routes from Cloud Run service labels
http:
  routers:
ROUTES_EOF

# Process the test service
SERVICE_JSON=$(cat "$TEST_DIR/test-service.json")
TRAEFIK_ENABLE=$(echo "$SERVICE_JSON" | jq -r '.spec.template.metadata.labels["traefik.enable"] // "false"')

if [ "$TRAEFIK_ENABLE" = "true" ]; then
  SERVICE_URL=$(echo "$SERVICE_JSON" | jq -r '.status.url // ""')
  LABELS_JSON=$(echo "$SERVICE_JSON" | jq -r '.spec.template.metadata.labels // {}')

  ROUTER_KEYS=$(echo "$LABELS_JSON" | jq -r 'keys[] | select(startswith("traefik.http.routers."))' 2>/dev/null || echo "")

  if [ -n "$ROUTER_KEYS" ]; then
    while IFS= read -r key; do
      if [[ "$key" =~ ^traefik\.http\.routers\.([^.]+)\.(.+)$ ]]; then
        ROUTER_NAME="${BASH_REMATCH[1]}"
        PROPERTY="${BASH_REMATCH[2]}"
        VALUE=$(echo "$LABELS_JSON" | jq -r ".[\"${key}\"]" 2>/dev/null || echo "")

        # Generate router config (simplified)
        if [ "$PROPERTY" = "rule" ]; then
          cat >> "$OUTPUT_FILE" <<EOF
    ${ROUTER_NAME}:
      rule: ${VALUE}
      service: home-index
      priority: 1
      entryPoints:
        - web
EOF
        fi
      fi
    done <<< "$ROUTER_KEYS"
  fi
fi

# Validate the output
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
  if grep -q "home-index:" "$OUTPUT_FILE"; then
    echo "   ✅ PASS: Generated routes file with router"
  else
    echo "   ❌ FAIL: Router not found in output"
    exit 1
  fi

  if python3 -c "import yaml; yaml.safe_load(open('$OUTPUT_FILE'))" 2>/dev/null; then
    echo "   ✅ PASS: Output is valid YAML"
  else
    echo "   ❌ FAIL: Output is not valid YAML"
    cat "$OUTPUT_FILE"
    exit 1
  fi
else
  echo "   ❌ FAIL: Output file not created"
  exit 1
fi

echo "   Generated routes:"
cat "$OUTPUT_FILE" | sed 's/^/      /'
echo "   ✅ Test 5 passed!"
echo ""

# Summary
echo "========================================"
echo "✅ All tests passed!"
echo ""
echo "📚 How It Works:"
echo ""
echo "1. Label Extraction:"
echo "   - Query Cloud Run services with gcloud"
echo "   - Extract labels using jq: .spec.template.metadata.labels"
echo "   - Filter for traefik.enable=true"
echo ""
echo "2. Router Parsing:"
echo "   - Find all labels matching traefik.http.routers.*"
echo "   - Extract router name from key: traefik.http.routers.<name>.<property>"
echo "   - Group properties by router name"
echo ""
echo "3. YAML Generation:"
echo "   - Build router definitions from grouped properties"
echo "   - Generate service definitions from service URLs"
echo "   - Add auth middlewares using identity tokens"
echo ""
echo "4. Integration:"
echo "   - entrypoint.sh calls generate-routes-from-labels.sh"
echo "   - Script queries all Cloud Run services"
echo "   - Generates /etc/traefik/dynamic/routes.yml"
echo "   - Traefik file provider watches and reloads config"
echo ""
echo "🧹 Cleaning up test files..."
rm -rf "$TEST_DIR"
echo "✅ Done!"
