#!/bin/bash
# Setup script to copy traefik-cloudrun-provider plugin source to plugins-local directory
# This script should be run from the e-skimming-labs root directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRAEFIK_DIR="$SCRIPT_DIR"
PLUGIN_SOURCE="$PROJECT_ROOT/../traefik-cloudrun-provider"
PLUGIN_DEST="$TRAEFIK_DIR/plugins-local/src/github.com/pci-tamper-protect/traefik-cloudrun-provider"

echo "🔧 Setting up Traefik Cloud Run plugin..."
echo "   Source: $PLUGIN_SOURCE"
echo "   Dest: $PLUGIN_DEST"

# Check if plugin source exists
if [ ! -d "$PLUGIN_SOURCE" ]; then
    echo "❌ ERROR: Plugin source directory not found: $PLUGIN_SOURCE"
    echo "   Make sure traefik-cloudrun-provider is a sibling directory of e-skimming-labs"
    exit 1
fi

# Create destination directory structure
mkdir -p "$PLUGIN_DEST"

# Copy plugin source files
echo "📦 Copying plugin source files..."
cp -r "$PLUGIN_SOURCE"/{plugin,provider,internal,go.mod,go.sum} "$PLUGIN_DEST/" 2>/dev/null || {
    echo "⚠️  Warning: Some files may not exist, continuing..."
}

# Copy .traefik.yml if it exists (required for Traefik v3.0 local plugins)
if [ -f "$PLUGIN_SOURCE/.traefik.yml" ]; then
    echo "📦 Copying .traefik.yml (required for local plugin mode)..."
    cp "$PLUGIN_SOURCE/.traefik.yml" "$PLUGIN_DEST/.traefik.yml"
    echo "✅ .traefik.yml copied"
else
    echo "⚠️  Warning: .traefik.yml not found in plugin source"
    echo "   Traefik v3.0 local plugins require .traefik.yml file"
fi

# Vendor directory IS required for Traefik v3.0 local plugins
# Traefik v3.0 uses Yaegi (embedded Go interpreter) which does NOT support Go modules
# Yaegi requires dependencies to be vendored in a vendor/ directory
# Note: go mod vendor should NOT include standard library packages - if it does, that's a bug
if [ -d "$PLUGIN_SOURCE/vendor" ]; then
    echo "📦 Copying vendor directory from source..."
    cp -r "$PLUGIN_SOURCE/vendor" "$PLUGIN_DEST/"
    echo "✅ Vendor directory copied"
else
    echo "📦 Generating vendor directory (required for Yaegi)..."
    cd "$PLUGIN_DEST"
    if command -v go &> /dev/null; then
        go mod vendor || {
            echo "⚠️  Warning: go mod vendor failed"
            echo "   Plugin may not compile correctly without vendor directory"
        }
        echo "✅ Vendor directory generated"
    else
        echo "❌ ERROR: go not found, cannot vendor dependencies"
        echo "   Vendor directory is REQUIRED for Traefik v3.0 local plugins"
        exit 1
    fi
fi

echo "✅ Plugin setup complete!"
echo "   Plugin location: $PLUGIN_DEST"
