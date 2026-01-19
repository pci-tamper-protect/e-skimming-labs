#!/bin/bash
# Helper script to unlock Terraform state
# Usage: ./unlock-terraform-state.sh [terraform-dir] [lock-id]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to terraform directory
TERRAFORM_DIR="${1:-terraform}"
LOCK_ID="$2"

cd "$SCRIPT_DIR/$TERRAFORM_DIR"

if [ -z "$LOCK_ID" ]; then
    echo "🔍 Checking for Terraform state locks..."
    echo ""
    echo "Run a terraform command to see the lock ID, then unlock with:"
    echo "  ./unlock-terraform-state.sh $TERRAFORM_DIR <LOCK_ID>"
    echo ""
    echo "Or to see lock info, try:"
    echo "  cd $TERRAFORM_DIR && terraform plan"
    exit 0
fi

echo "🔓 Unlocking Terraform state..."
echo "   Lock ID: $LOCK_ID"
echo "   Directory: $TERRAFORM_DIR"
echo ""
echo "yes" | terraform force-unlock "$LOCK_ID"

echo ""
echo "✅ State unlocked successfully!"

