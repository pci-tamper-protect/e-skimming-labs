#!/usr/bin/env bash
# Generate catalog-info.yaml based on services and labs
# This script scans the codebase and generates a comprehensive catalog-info.yaml file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_FILE="${REPO_ROOT}/catalog-info.yaml"

cd "${REPO_ROOT}"

# Get git information
GIT_COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT_SHA_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT_MESSAGE=$(git log -1 --pretty=%B 2>/dev/null | head -1 || echo "unknown")
GIT_COMMIT_AUTHOR=$(git log -1 --pretty=%an 2>/dev/null || echo "unknown")
GIT_COMMIT_DATE=$(git log -1 --pretty=%ai 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_IS_DIRTY=$(git diff --quiet && echo "false" || echo "true")
GIT_REPO=$(git config --get remote.origin.url 2>/dev/null || echo "unknown")

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

# Discover services
declare -a SERVICES=()
declare -a LABS=()

# Find shared components/services
if [ -d "deploy/shared-components" ]; then
  for service_dir in deploy/shared-components/*/; do
    if [ -d "${service_dir}" ] && [ -f "${service_dir}main.go" ] || [ -f "${service_dir}Dockerfile" ]; then
      service_name=$(basename "${service_dir}")
      SERVICES+=("${service_name}")
    fi
  done
fi

# Find labs
if [ -d "labs" ]; then
  for lab_dir in labs/*/; do
    if [ -d "${lab_dir}" ] && [ -f "${lab_dir}Dockerfile" ]; then
      lab_name=$(basename "${lab_dir}")
      # Extract lab number and name (e.g., "01-basic-magecart" -> "lab-01-basic-magecart")
      if [[ "${lab_name}" =~ ^[0-9]+- ]]; then
        LABS+=("lab-${lab_name}")
      fi
    fi
  done
fi

# Generate YAML
cat > "${OUTPUT_FILE}" <<EOF
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: e-skimming-labs
  description: Interactive e-skimming attack labs for cybersecurity training
  annotations:
    backstage.io/managed-by-location: file:./catalog-info.yaml
    backstage.io/managed-by-origin-location: file:./catalog-info.yaml
    ptp.io/service-type: web-service
    ptp.io/deployment-environment: production
    ptp.io/team: cybersecurity
    ptp.io/domain: payment-security
spec:
  type: service
  lifecycle: production
  owner: cybersecurity
  system: ptp-platform
ptp:
  service:
    name: e-skimming-labs
    version: 1.0.0
    description: Interactive e-skimming attack labs for cybersecurity training
    team: cybersecurity
    domain: payment-security
    environment: production
    deployment:
      timestamp: ${TIMESTAMP}
      hostname: unknown
      user: $(whoami)
      pipeline: github-actions
      build-number: unknown
      image-tag: latest
  git:
    commit_sha: ${GIT_COMMIT_SHA}
    commit_sha_short: ${GIT_COMMIT_SHA_SHORT}
    commit_message: ${GIT_COMMIT_MESSAGE}
    commit_author: ${GIT_COMMIT_AUTHOR}
    commit_date: '${GIT_COMMIT_DATE}'
    branch: ${GIT_BRANCH}
    is_dirty: ${GIT_IS_DIRTY}
    source: live_git
    repository: ${GIT_REPO}
    pull_request: null
  dependencies:
    runtime:
      services:
EOF

# Add services to dependencies
for service in "${SERVICES[@]}"; do
  echo "        - ${service}" >> "${OUTPUT_FILE}"
done

cat >> "${OUTPUT_FILE}" <<EOF
      labs:
EOF

# Add labs to dependencies
for lab in "${LABS[@]}"; do
  echo "        - ${lab}" >> "${OUTPUT_FILE}"
done

cat >> "${OUTPUT_FILE}" <<EOF
    build:
      base_images:
        - go-base:latest
        - alpine-base:latest
    external: []
  monitoring:
    health-check: /health
    metrics-endpoint: /metrics
    logs-level: info
    alerting:
      enabled: true
      channels:
        - '#platform-alerts'
  security:
    vulnerability-scan: true
    dependency-check: true
    secrets-scan: true
    last-scan: ${TIMESTAMP}
  compliance:
    pci-dss: true
    soc2: true
    gdpr: true
    last-audit: ${TIMESTAMP}
EOF

echo "✅ Generated catalog-info.yaml"
echo "   Services found: ${#SERVICES[@]} (${SERVICES[*]})"
echo "   Labs found: ${#LABS[@]} (${LABS[*]})"
echo "   Output: ${OUTPUT_FILE}"

