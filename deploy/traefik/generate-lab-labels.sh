#!/bin/bash
# Generate Cloud Run labels from docker-compose.yml traefik labels
# This makes docker-compose.yml the single source of truth for routing.
#
# Usage: ./deploy/traefik/generate-lab-labels.sh [path-to-docker-compose.yml]
#
# Requirements: yq (https://github.com/mikefarah/yq)
#   brew install yq  (macOS)
#   Pre-installed on GitHub Actions runners
#
# Output: deploy/traefik/lab-labels.sh (sourceable bash file with get_lab_labels function)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${1:-${REPO_ROOT}/docker-compose.yml}"
OUTPUT_FILE="${SCRIPT_DIR}/lab-labels.sh"

if ! command -v yq &>/dev/null; then
  echo "❌ yq is required but not installed."
  echo "   Install: brew install yq (macOS) or see https://github.com/mikefarah/yq"
  exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ docker-compose.yml not found: $COMPOSE_FILE"
  exit 1
fi

echo "📋 Generating Cloud Run labels from: $COMPOSE_FILE"

# Convert a single compose traefik label to Cloud Run format
# Args: $1 = compose label string like 'traefik.http.routers.lab1.rule=PathPrefix(`/lab1`)'
# Outputs the Cloud Run key=value pair
convert_label() {
  local label="$1"
  local key="${label%%=*}"
  local value="${label#*=}"

  # Skip non-traefik labels
  [[ "$key" != traefik.* ]] && return

  # Convert loadbalancer.server.port → lb_port with value override to 8080
  if [[ "$key" == *".loadbalancer.server.port" ]]; then
    # Extract service name: traefik.http.services.<name>.loadbalancer.server.port
    local svc_name
    svc_name=$(echo "$key" | sed 's/traefik\.http\.services\.\(.*\)\.loadbalancer\.server\.port/\1/')
    echo "traefik_http_services_${svc_name}_lb_port=8080"
    return
  fi

  # Convert key: dots → underscores
  local cr_key="${key//\./_}"

  # Handle rule values: always use rule_id shorthand
  # Cloud Run labels only allow lowercase letters, numbers, underscores, and dashes.
  # Rule values like PathPrefix(`/lab1`) contain backticks, parens, uppercase — not allowed.
  if [[ "$key" == *".rule" ]]; then
    # Extract router name from key: traefik.http.routers.<router-name>.rule
    local router_name
    router_name=$(echo "$key" | sed 's/traefik\.http\.routers\.\(.*\)\.rule/\1/')
    cr_key="${cr_key%_rule}_rule_id"
    value="$router_name"
    echo "${cr_key}=${value}"
    return
  fi

  # Handle middlewares: @file → -file, comma-separated → __ separated
  if [[ "$key" == *".middlewares" ]]; then
    value="${value//@file/-file}"
    value="${value//,/__}"
    echo "${cr_key}=${value}"
    return
  fi

  # All other labels: straight conversion
  echo "${cr_key}=${value}"
}

# Start generating the output file
cat > "$OUTPUT_FILE" << 'HEADER'
#!/bin/bash
# AUTO-GENERATED from docker-compose.yml by generate-lab-labels.sh
# Do not edit manually. Re-run: ./deploy/traefik/generate-lab-labels.sh

get_lab_labels() {
  local service="$1"
  case "$service" in
HEADER

# Get all services that have traefik.enable=true in their labels
services=$(yq -r '.services | to_entries[] | select(.value.labels[]? == "traefik.enable=true" or .value.labels[]? == "\"traefik.enable=true\"") | .key' "$COMPOSE_FILE" 2>/dev/null)

for service in $services; do
  echo "   Processing: $service"

  # Get all labels for this service
  labels=$(yq -r ".services.${service}.labels[]" "$COMPOSE_FILE" 2>/dev/null)

  # Build Cloud Run label string
  cr_labels=""
  while IFS= read -r label; do
    # Remove surrounding quotes if present
    label="${label#\"}"
    label="${label%\"}"

    # Skip empty lines and non-traefik labels
    [[ -z "$label" ]] && continue
    [[ "$label" != traefik.* ]] && continue

    converted=$(convert_label "$label")
    [[ -z "$converted" ]] && continue

    if [ -n "$cr_labels" ]; then
      cr_labels="${cr_labels},${converted}"
    else
      cr_labels="${converted}"
    fi
  done <<< "$labels"

  # Escape backticks for safe use in double-quoted echo statements
  cr_labels_escaped="${cr_labels//\`/\\\`}"

  # Write case entry
  cat >> "$OUTPUT_FILE" << EOF
    ${service})
      echo "${cr_labels_escaped}"
      ;;
EOF
done

# Close the case statement and function
cat >> "$OUTPUT_FILE" << 'FOOTER'
    *)
      echo "traefik_enable=true"
      echo "⚠️  Unknown service: $service" >&2
      return 1
      ;;
  esac
}
FOOTER

chmod +x "$OUTPUT_FILE"
echo "✅ Generated: $OUTPUT_FILE"
echo ""
echo "Usage:"
echo "  source $OUTPUT_FILE"
echo "  get_lab_labels \"lab1-vulnerable-site\""
