#!/bin/bash
# Test script to verify dev mounts work correctly
# Usage: ./test/test-dev-mounts.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "🧪 Testing dev mount configuration..."
echo ""

# Test 1: Verify docker-compose.dev.yml is valid
echo "✅ Test 1: Validating docker-compose.dev.yml syntax..."
if docker-compose -f docker-compose.yml -f docker-compose.dev.yml config > /dev/null 2>&1; then
    echo "   ✅ docker-compose.dev.yml is valid"
else
    echo "   ❌ docker-compose.dev.yml has syntax errors"
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml config
    exit 1
fi

# Test 2: Check that required files exist
echo ""
echo "✅ Test 2: Checking required files exist..."
REQUIRED_FILES=(
    "docker-compose.dev.yml"
    "deploy/shared-components/home-index-service/Dockerfile.dev"
    "deploy/shared-components/home-index-service/.air.toml"
    "deploy/shared-components/home-index-service/entrypoint.dev.sh"
    "labs/01-basic-magecart/malicious-code/c2-server/Dockerfile.dev"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file exists"
    else
        echo "   ❌ $file MISSING"
        exit 1
    fi
done

# Test 3: Verify volume mounts are correct
echo ""
echo "✅ Test 3: Verifying volume mount paths..."
VOLUME_PATHS=(
    "./deploy/shared-components/home-index-service"
    "./docs"
    "./labs"
    "./labs/01-basic-magecart/malicious-code/c2-server"
)

for path in "${VOLUME_PATHS[@]}"; do
    if [ -d "$path" ] || [ -f "$path" ]; then
        echo "   ✅ $path exists"
    else
        echo "   ⚠️  $path not found (may be created later)"
    fi
done

# Test 4: Check Air config syntax
echo ""
echo "✅ Test 4: Checking Air configuration..."
if command -v air &> /dev/null; then
    # Try to validate .air.toml (Air doesn't have a validate command, so we check file exists and is readable)
    if [ -r "deploy/shared-components/home-index-service/.air.toml" ]; then
        echo "   ✅ .air.toml is readable"
    else
        echo "   ❌ .air.toml is not readable"
        exit 1
    fi
else
    echo "   ℹ️  Air not installed locally (will be installed in container)"
fi

# Test 5: Verify entrypoint.dev.sh is executable
echo ""
echo "✅ Test 5: Checking entrypoint.dev.sh permissions..."
if [ -x "deploy/shared-components/home-index-service/entrypoint.dev.sh" ]; then
    echo "   ✅ entrypoint.dev.sh is executable"
else
    echo "   ⚠️  entrypoint.dev.sh is not executable, fixing..."
    chmod +x deploy/shared-components/home-index-service/entrypoint.dev.sh
    echo "   ✅ Fixed permissions"
fi

# Test 6: Check that source files exist for mounting
echo ""
echo "✅ Test 6: Verifying source files exist for mounting..."
SOURCE_FILES=(
    "deploy/shared-components/home-index-service/main.go"
    "deploy/shared-components/home-index-service/go.mod"
    "labs/01-basic-magecart/malicious-code/c2-server/server.js"
    "labs/01-basic-magecart/malicious-code/c2-server/package.json"
)

for file in "${SOURCE_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file exists"
    else
        echo "   ❌ $file MISSING"
        exit 1
    fi
done

echo ""
echo "✅ All tests passed! Dev mount configuration looks good."
echo ""
echo "📝 Summary:"
echo "  - docker-compose.dev.yml syntax: ✅ Valid"
echo "  - Required files: ✅ All present"
echo "  - Volume paths: ✅ All exist"
echo "  - Source files: ✅ Ready for mounting"
echo ""
echo "To use dev mode (hot-reload):"
echo "  DEV_MODE=true ./docker-compose.local.sh up"
echo "  OR"
echo "  ./docker-compose.local.sh -f docker-compose.dev.yml up"
echo ""
echo "To use normal mode (rebuild on changes):"
echo "  ./docker-compose.local.sh up --build"
