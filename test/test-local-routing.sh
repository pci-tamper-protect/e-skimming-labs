#!/bin/bash
# Step-by-step test for writeup routing

set -e

echo "=========================================="
echo "Step 1: Check if README files exist locally"
echo "=========================================="
for lab in "01-basic-magecart" "02-dom-skimming" "03-extension-hijacking"; do
    if [ -f "docs/labs/$lab/README.md" ]; then
        echo "✅ docs/labs/$lab/README.md exists ($(wc -l < docs/labs/$lab/README.md) lines)"
    else
        echo "❌ docs/labs/$lab/README.md NOT FOUND"
        echo "   Creating it now..."
        mkdir -p "docs/labs/$lab"
        cp "labs/$lab/README.md" "docs/labs/$lab/README.md"
        echo "   ✅ Created"
    fi
done

echo ""
echo "=========================================="
echo "Step 2: Check if home-index service is running"
echo "=========================================="
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "✅ Service is running on http://localhost:3000"
    curl -s http://localhost:3000/health
    echo ""
else
    echo "❌ Service is NOT running on http://localhost:3000"
    echo "   Start it with: docker-compose up home-index"
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 3: Test writeup routes"
echo "=========================================="
for lab_num in "01" "02" "03"; do
    url="http://localhost:3000/lab-${lab_num}-writeup"
    echo "Testing: $url"
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>&1)
    if [ "$response" = "200" ]; then
        echo "  ✅ Route works (HTTP $response)"
    else
        echo "  ❌ Route failed (HTTP $response)"
        echo "  Response body:"
        curl -s "$url" | head -20
    fi
    echo ""
done

echo ""
echo "=========================================="
echo "Step 4: Check file paths inside container"
echo "=========================================="
echo "To check file paths inside the container, run:"
echo "  docker exec e-skimming-labs-home-index ls -la /app/docs/labs/"
echo "  docker exec e-skimming-labs-home-index test -f /app/docs/labs/01-basic-magecart/README.md && echo 'File exists' || echo 'File missing'"

echo ""
echo "=========================================="
echo "Step 5: Test direct file read (if running locally)"
echo "=========================================="
if [ -f "docs/labs/01-basic-magecart/README.md" ]; then
    echo "✅ Can read file locally"
    head -5 "docs/labs/01-basic-magecart/README.md"
else
    echo "❌ Cannot read file locally"
fi
