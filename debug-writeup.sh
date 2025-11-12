#!/bin/bash
# Comprehensive debugging script for writeup routing

echo "=========================================="
echo "WRITEUP ROUTING DEBUG SCRIPT"
echo "=========================================="
echo ""

echo "STEP 1: Verify README files exist locally"
echo "------------------------------------------"
for lab in "01-basic-magecart" "02-dom-skimming" "03-extension-hijacking"; do
    file="docs/labs/$lab/README.md"
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo "✅ $file exists ($lines lines)"
    else
        echo "❌ $file NOT FOUND - Creating it..."
        mkdir -p "docs/labs/$lab"
        if [ -f "labs/$lab/README.md" ]; then
            cp "labs/$lab/README.md" "$file"
            echo "   ✅ Created from labs/$lab/README.md"
        else
            echo "   ❌ Source file labs/$lab/README.md also not found!"
        fi
    fi
done
echo ""

echo "STEP 2: Check if container is running"
echo "--------------------------------------"
if docker ps | grep -q e-skimming-labs-home-index; then
    echo "✅ Container is running"
    CONTAINER_RUNNING=true
else
    echo "❌ Container is NOT running"
    echo "   Start it with: docker-compose up -d home-index"
    CONTAINER_RUNNING=false
fi
echo ""

if [ "$CONTAINER_RUNNING" = true ]; then
    echo "STEP 3: Check files inside container"
    echo "--------------------------------------"
    echo "Checking /app/docs structure:"
    docker exec e-skimming-labs-home-index ls -la /app/docs/ 2>&1 | head -10 || echo "Cannot list /app/docs"
    echo ""

    echo "Checking for labs directory:"
    docker exec e-skimming-labs-home-index test -d /app/docs/labs && echo "✅ /app/docs/labs exists" || echo "❌ /app/docs/labs does NOT exist"
    echo ""

    echo "Checking for README files:"
    for lab in "01-basic-magecart" "02-dom-skimming" "03-extension-hijacking"; do
        if docker exec e-skimming-labs-home-index test -f "/app/docs/labs/$lab/README.md" 2>/dev/null; then
            echo "✅ /app/docs/labs/$lab/README.md exists in container"
        else
            echo "❌ /app/docs/labs/$lab/README.md NOT FOUND in container"
        fi
    done
    echo ""

    echo "STEP 4: Check service health"
    echo "-----------------------------"
    if curl -s http://localhost:3000/health > /dev/null 2>&1; then
        echo "✅ Service is responding on http://localhost:3000/health"
        curl -s http://localhost:3000/health
        echo ""
    else
        echo "❌ Service is NOT responding"
    fi
    echo ""

    echo "STEP 5: Test writeup routes"
    echo "--------------------------"
    for lab_num in "01" "02" "03"; do
        url="http://localhost:3000/lab-${lab_num}-writeup"
        echo "Testing: $url"
        http_code=$(curl -s -o /tmp/writeup-response.html -w "%{http_code}" "$url" 2>&1)
        if [ "$http_code" = "200" ]; then
            echo "  ✅ Route works (HTTP $http_code)"
        else
            echo "  ❌ Route failed (HTTP $http_code)"
            echo "  Response:"
            head -5 /tmp/writeup-response.html
        fi
        echo ""
    done

    echo "STEP 6: Check container logs"
    echo "-----------------------------"
    echo "Recent logs (last 20 lines):"
    docker logs e-skimming-labs-home-index --tail 20 2>&1 | grep -i "writeup\|readme\|lab" || echo "No writeup-related logs found"
    echo ""
fi

echo "STEP 7: Rebuild instructions"
echo "----------------------------"
echo "If files are missing in container, rebuild with:"
echo "  docker-compose build home-index"
echo "  docker-compose up -d home-index"
echo ""
echo "To see real-time logs:"
echo "  docker logs -f e-skimming-labs-home-index"
