#!/bin/bash
# Deploy Traefik to Cloud Run
# Wrapper for the sidecar Traefik 3.0 deployment (default mechanism)
# Usage: ./deploy/traefik/deploy.sh [stg|prd]
#
# For the legacy plugin-only v2 deployment, use deploy-plugin-v2.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/deploy-sidecar-traefik-3.0.sh" "$@"
