#!/bin/bash
# Refresh Traefik routes by regenerating routes.yml
# This script can be called:
# - Periodically (via cron or Cloud Scheduler)
# - On-demand (via HTTP endpoint)
# - Via Eventarc (on Cloud Run service changes)

set -e

OUTPUT_FILE="${1:-/etc/traefik/dynamic/routes.yml}"
LOG_FILE="${2:-/tmp/traefik-refresh.log}"

echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - Refreshing Traefik routes..." >> "$LOG_FILE"

# Run the generation script
if [ -f "/app/generate-routes-from-labels.sh" ]; then
  if /app/generate-routes-from-labels.sh "$OUTPUT_FILE" >> "$LOG_FILE" 2>&1; then
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - Routes refreshed successfully" >> "$LOG_FILE"
    exit 0
  else
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - Route refresh failed" >> "$LOG_FILE"
    exit 1
  fi
else
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - Generation script not found" >> "$LOG_FILE"
  exit 1
fi
