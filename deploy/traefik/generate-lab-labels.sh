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

# Base labels added by every deploy-all.sh invocation (environment, component/lab, project).
# Traefik labels per service must not exceed 64 - BASE_LABEL_COUNT.
BASE_LABEL_COUNT=3

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

# validate_cr_labels SERVICE LABELS_STRING
#
# Validates a comma-separated key=value label string against Cloud Run constraints:
#   - Key:   ^[a-z][a-z0-9_-]*$   max 63 chars
#   - Value: ^[a-z0-9_-]*$        max 63 chars (empty allowed)
#   - Total labels (including BASE_LABEL_COUNT base labels) <= 64
#
# Exits non-zero and prints all violations.
validate_cr_labels() {
  local service="$1"
  local labels_str="$2"
  local errors=0

  # Count labels
  local count=0
  IFS=',' read -ra pairs <<< "$labels_str"
  count=${#pairs[@]}
  local total=$((count + BASE_LABEL_COUNT))
  if [ "$total" -gt 64 ]; then
    echo "❌ VALIDATION [$service]: $total labels total ($count Traefik + $BASE_LABEL_COUNT base) exceeds Cloud Run max of 64"
    errors=$((errors + 1))
  fi

  for pair in "${pairs[@]}"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"

    # Key format
    if [[ ! "$key" =~ ^[a-z][a-z0-9_-]*$ ]]; then
      echo "❌ VALIDATION [$service]: Invalid key format: '$key'"
      echo "   Keys must match ^[a-z][a-z0-9_-]*\$"
      errors=$((errors + 1))
    elif [ "${#key}" -gt 63 ]; then
      echo "❌ VALIDATION [$service]: Key too long (${#key}/63): '$key'"
      errors=$((errors + 1))
    fi

    # Value format (empty is allowed)
    if [[ -n "$value" && ! "$value" =~ ^[a-z0-9_-]*$ ]]; then
      echo "❌ VALIDATION [$service]: Invalid value for '$key': '$value'"
      echo "   Values must match ^[a-z0-9_-]*\$ (lowercase, digits, hyphens, underscores only)"
      errors=$((errors + 1))
    elif [ "${#value}" -gt 63 ]; then
      echo "❌ VALIDATION [$service]: Value too long (${#value}/63) for '$key': '$value'"
      errors=$((errors + 1))
    fi
  done

  if [ "$errors" -gt 0 ]; then
    echo "   Fix the docker-compose.yml labels for service '$service' and re-run generate-lab-labels.sh"
    return 1
  fi
}

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

# validate_cr_labels SERVICE LABELS_STRING
# Validates Cloud Run label constraints. Exits non-zero on any violation.
# Called automatically by get_lab_labels — sourcing scripts will abort on bad labels.
validate_cr_labels() {
  local service="$1"
  local labels_str="$2"
  local base_label_count="${3:-3}"
  local errors=0

  IFS=',' read -ra pairs <<< "$labels_str"
  local count=${#pairs[@]}
  local total=$((count + base_label_count))
  if [ "$total" -gt 64 ]; then
    echo "❌ VALIDATION [$service]: $total labels total ($count Traefik + $base_label_count base) exceeds Cloud Run max of 64" >&2
    errors=$((errors + 1))
  fi

  for pair in "${pairs[@]}"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"
    if [[ ! "$key" =~ ^[a-z][a-z0-9_-]*$ ]]; then
      echo "❌ VALIDATION [$service]: Invalid key format: '$key'" >&2
      errors=$((errors + 1))
    elif [ "${#key}" -gt 63 ]; then
      echo "❌ VALIDATION [$service]: Key too long (${#key}/63): '$key'" >&2
      errors=$((errors + 1))
    fi
    if [[ -n "$value" && ! "$value" =~ ^[a-z0-9_-]*$ ]]; then
      echo "❌ VALIDATION [$service]: Invalid value for '$key': '$value'" >&2
      errors=$((errors + 1))
    elif [ "${#value}" -gt 63 ]; then
      echo "❌ VALIDATION [$service]: Value too long (${#value}/63) for '$key': '$value'" >&2
      errors=$((errors + 1))
    fi
  done

  if [ "$errors" -gt 0 ]; then
    echo "   Regenerate with: ./deploy/traefik/generate-lab-labels.sh" >&2
    return 1
  fi
}

get_lab_labels() {
  local service="$1"
  local labels
  case "$service" in
HEADER

# Get all services that have traefik.enable=true in their labels
services=$(yq -r '.services | to_entries[] | select(.value.labels[]? == "traefik.enable=true" or .value.labels[]? == "\"traefik.enable=true\"") | .key' "$COMPOSE_FILE" 2>/dev/null)

generation_errors=0

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

  # Validate before writing
  if ! validate_cr_labels "$service" "$cr_labels"; then
    generation_errors=$((generation_errors + 1))
    continue
  fi

  # Escape backticks for safe use in double-quoted echo statements
  cr_labels_escaped="${cr_labels//\`/\\\`}"

  # Write case entry
  cat >> "$OUTPUT_FILE" << EOF
    ${service})
      labels="${cr_labels_escaped}"
      ;;
EOF
done

if [ "$generation_errors" -gt 0 ]; then
  echo ""
  echo "❌ Generation failed: $generation_errors service(s) have invalid Cloud Run labels"
  rm -f "$OUTPUT_FILE"
  exit 1
fi

# Close the case statement and function — validate on every call
cat >> "$OUTPUT_FILE" << 'FOOTER'
    *)
      echo "⚠️  Unknown service: $service" >&2
      return 1
      ;;
  esac
  validate_cr_labels "$service" "$labels" || return 1
  echo "$labels"
}
FOOTER

chmod +x "$OUTPUT_FILE"
echo "✅ Generated: $OUTPUT_FILE"
echo ""
echo "Usage:"
echo "  source $OUTPUT_FILE"
echo "  get_lab_labels \"lab1-vulnerable-site\""
