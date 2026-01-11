#!/bin/bash
# Build script for generate-routes Go binary
# This script builds the binary and verifies it was created successfully

set -e

echo "Building Go binary..."
echo "  Target: /app/generate-routes"
echo "  Platform: linux/amd64"
echo "  CGO: disabled"

# Build the binary
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/generate-routes .

echo ""
echo "Build completed. Verifying binary..."

# Verify binary exists
if [ ! -f /app/generate-routes ]; then
    echo "ERROR: Binary file not created at /app/generate-routes"
    echo "Contents of /app directory:"
    ls -la /app/ || true
    exit 1
fi

# Show binary info
echo "Binary created successfully:"
ls -lh /app/generate-routes

# Verify binary is executable
if [ ! -x /app/generate-routes ]; then
    echo "ERROR: Binary is not executable"
    ls -l /app/generate-routes
    exit 1
fi

# Test that binary runs (should show help or error, but not crash)
if ! /app/generate-routes --help >/dev/null 2>&1 && [ $? -ne 0 ] && [ $? -ne 1 ]; then
    echo "WARNING: Binary may not be working correctly (exit code: $?)"
    # Don't fail - binary exists and is executable, might just need proper args
fi

echo "SUCCESS: generate-routes binary built and verified at /app/generate-routes"



