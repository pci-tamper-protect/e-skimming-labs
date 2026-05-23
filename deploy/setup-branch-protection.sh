#!/bin/bash
# Wrapper: apply branch protection rules for this repo via the pcioasis-ops primitive.
# Usage: ./deploy/setup-branch-protection.sh [--dry-run]
#
# The primitive lives in ~/projectos/pcioasis-ops/github/setup-branch-protection.sh
# This wrapper pins the REPO_OWNER and REPO_NAME so you never have to pass them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIMITIVE="${HOME}/projectos/pcioasis-ops/github/setup-branch-protection.sh"

if [ ! -f "$PRIMITIVE" ]; then
  echo "❌ pcioasis-ops primitive not found: $PRIMITIVE"
  echo "   Ensure ~/projectos/pcioasis-ops is checked out."
  exit 1
fi

REPO_OWNER=pci-tamper-protect \
REPO_NAME=e-skimming-labs \
"$PRIMITIVE" "$@"
