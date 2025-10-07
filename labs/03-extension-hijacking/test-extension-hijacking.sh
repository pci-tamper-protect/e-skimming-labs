#!/bin/bash

# E-Skimming Lab 3 - Extension Hijacking Testing
# FOR EDUCATIONAL PURPOSES ONLY

set -e

echo "🧪 E-Skimming Lab 3 - Extension Hijacking Testing"
echo "================================================"

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to start vulnerable site
start_vulnerable_site() {
    echo "🌐 Starting vulnerable e-commerce site on port 8080..."
    cd vulnerable-site
    python3 -m http.server 8080 > /dev/null 2>&1 &
    SITE_PID=$!
    cd ..

    # Wait for site to start
    sleep 2
    if curl -s http://localhost:8080/index.html > /dev/null; then
        echo "✅ Vulnerable site running at http://localhost:8080"
    else
        echo "❌ Failed to start vulnerable site"
        exit 1
    fi
}

# Function to start data collection server
start_data_server() {
    echo "📡 Starting extension data collection server on port 3002..."
    cd test-server

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "📦 Installing server dependencies..."
        npm install
    fi

    node extension-data-server.js > /dev/null 2>&1 &
    SERVER_PID=$!
    cd ..

    # Wait for server to start
    sleep 3
    if curl -s http://localhost:3002/health > /dev/null; then
        echo "✅ Data collection server running at http://localhost:3002"
    else
        echo "❌ Failed to start data collection server"
        exit 1
    fi
}

# Function to cleanup
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."

    if [ ! -z "$SITE_PID" ]; then
        kill $SITE_PID 2>/dev/null || true
    fi

    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
    fi

    # Kill any remaining processes on our ports
    lsof -ti :8080 | xargs kill -9 2>/dev/null || true
    lsof -ti :3002 | xargs kill -9 2>/dev/null || true

    echo "✅ Cleanup complete"
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check for required tools
command -v python3 >/dev/null 2>&1 || { echo "❌ python3 is required but not installed."; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ node is required but not installed."; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "❌ npm is required but not installed."; exit 1; }

echo "✅ Prerequisites check passed"

# Check if ports are available
echo "🔍 Checking port availability..."

if check_port 8080; then
    echo "❌ Port 8080 is already in use. Please free this port first."
    exit 1
fi

if check_port 3002; then
    echo "❌ Port 3002 is already in use. Please free this port first."
    exit 1
fi

echo "✅ Ports 8080 and 3002 are available"

# Start services
start_vulnerable_site
start_data_server

echo ""
echo "🚀 Lab 3 Environment Ready!"
echo "=========================="
echo "📱 Vulnerable Site: http://localhost:8080"
echo "📊 Data Server Status: http://localhost:3002/status"
echo "📡 Data Collection: http://localhost:3002/skimmed-data"
echo ""

# Manual testing instructions
echo "🧪 Manual Testing Steps:"
echo "1. Load the legitimate extension in Chrome:"
echo "   - Open chrome://extensions/"
echo "   - Enable Developer mode"
echo "   - Click 'Load unpacked' → select 'legitimate-extension/'"
echo ""
echo "2. Test legitimate functionality:"
echo "   - Visit http://localhost:8080"
echo "   - Fill out checkout forms"
echo "   - Observe extension validation features"
echo ""
echo "3. Replace with malicious extension:"
echo "   - Remove legitimate extension"
echo "   - Load 'malicious-extension/' instead"
echo "   - Fill forms again and monitor data collection"
echo ""
echo "4. Monitor data collection:"
echo "   - Check http://localhost:3002/status for statistics"
echo "   - View captured data at http://localhost:3002/export/$(date +%Y-%m-%d)"
echo ""

# Run automated tests if available
if [ -f "test-automation.js" ]; then
    echo "🤖 Running automated tests..."
    echo "============================="

    # Check if puppeteer is available
    if command -v node >/dev/null 2>&1; then
        if node -e "require('puppeteer')" 2>/dev/null; then
            echo "Running extension hijacking automation..."
            node test-automation.js
        else
            echo "⚠️  Puppeteer not installed. Skipping automated tests."
            echo "   Install with: npm install puppeteer"
        fi
    fi
else
    echo "ℹ️  No automated test file found. Manual testing only."
fi

echo ""
echo "📊 Current Status:"
echo "=================="

# Check data collection server stats
echo "🔍 Checking data collection server..."
if curl -s http://localhost:3002/status > /dev/null; then
    curl -s http://localhost:3002/status | node -e "
        const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
        console.log('📈 Server Stats:');
        console.log('  Total Requests:', data.stats.totalSessions || 0);
        console.log('  Sensitive Fields:', data.stats.totalFields || 0);
        console.log('  Forms Processed:', data.stats.totalForms || 0);
        console.log('  Uptime:', Math.floor((Date.now() - data.stats.startTime) / 1000) + 's');
    " 2>/dev/null || echo "  Status: Running (no data yet)"
else
    echo "❌ Data collection server not responding"
fi

echo ""
echo "🎯 Lab Objectives:"
echo "=================="
echo "1. ✅ Understand extension privilege escalation"
echo "2. ✅ Observe real-time data collection across sites"
echo "3. ✅ Learn stealth techniques and persistence"
echo "4. ✅ Practice detection of extension-based attacks"
echo ""

echo "⚠️  Press Ctrl+C to stop all services and cleanup"
echo ""

# Keep services running until user stops
echo "🔄 Services running... (Ctrl+C to stop)"
while true; do
    sleep 5

    # Check if services are still running
    if ! curl -s http://localhost:8080 > /dev/null; then
        echo "❌ Vulnerable site stopped unexpectedly"
        break
    fi

    if ! curl -s http://localhost:3002/health > /dev/null; then
        echo "❌ Data collection server stopped unexpectedly"
        break
    fi
done