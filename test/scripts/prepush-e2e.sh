#!/usr/bin/env bash
# Run CI-parity E2E specs against the local Traefik stack (localhost:8080).
set -euo pipefail

exec 1>&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASE_URL="${BASE_URL:-http://localhost:8080}"

log() {
  echo "$@" >&2
}

log "DEBUG: prepush-e2e BASE_URL=${BASE_URL}"

if ! curl -sf --max-time 5 "${BASE_URL}/" >/dev/null; then
  log "ERROR: Lab stack not reachable at ${BASE_URL}"
  log "Start it from the repo root, e.g.: ./docker-labs.sh start  or  docker compose up -d traefik home-index shared-c2"
  exit 1
fi

log "OK: ${BASE_URL} is up"

cd "${TEST_DIR}"

export TEST_ENV=local
export BASE_URL

SPECS=(
  e2e/mobile-layout.spec.js
  e2e/c2-dashboard-display.spec.js
  e2e/global-navigation.spec.js
  e2e/lab2-card-capture.spec.js
)

log "Running Playwright (chromium): ${SPECS[*]}"
npx playwright test "${SPECS[@]}" --project=chromium "$@"

log "prepush-e2e: all specs passed"
