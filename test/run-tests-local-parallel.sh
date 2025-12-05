#!/bin/bash
# Run Playwright tests in parallel (faster but uses more resources)
#
# This runs test suites in parallel, which is faster but:
# - Uses more CPU/memory
# - Output may be interleaved
# - Harder to debug failures
#
# Usage:
#   ./test/run-tests-local-parallel.sh [all|global|1|2|3]

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the project root (parent of test directory)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Running tests in PARALLEL mode (faster execution)"
echo "⚠️  Note: This uses more resources and output may be interleaved"
echo ""

# Set test environment
export TEST_ENV=local

# Determine which tests to run
MODE=${1:-"all"}

# Function to run tests in background and capture output
run_test_suite() {
    local name=$1
    local dir=$2
    local log_file="/tmp/test-${name}.log"
    
    echo "▶️  Starting ${name} tests..."
    (
        cd "$dir"
        npm test > "$log_file" 2>&1
        echo "✅ ${name} tests completed"
    ) &
    echo "$!" > "/tmp/test-${name}.pid"
    echo "$log_file"
}

# Function to wait for all background jobs and show results
wait_for_tests() {
    local log_files=("$@")
    local failed=0
    
    echo ""
    echo "⏳ Waiting for all tests to complete..."
    wait
    
    echo ""
    echo "📊 Test Results:"
    echo "=================="
    
    for log_file in "${log_files[@]}"; do
        local name=$(basename "$log_file" .log | sed 's/test-//')
        echo ""
        echo "━━━ ${name} ━━━"
        if [ -f "$log_file" ]; then
            tail -20 "$log_file"
        else
            echo "⚠️  No log file found"
        fi
    done
    
    echo ""
    echo "📁 Full logs available in: /tmp/test-*.log"
}

case $MODE in
  global)
    echo "📍 Running global tests only"
    cd "$PROJECT_ROOT/test"
    npm test
    ;;
  1|lab1)
    echo "📍 Running Lab 1 tests only"
    cd "$PROJECT_ROOT/labs/01-basic-magecart/test"
    npm test
    ;;
  2|lab2)
    echo "📍 Running Lab 2 tests only"
    cd "$PROJECT_ROOT/labs/02-dom-skimming/test"
    npm test
    ;;
  3|lab3)
    echo "📍 Running Lab 3 tests only"
    cd "$PROJECT_ROOT/labs/03-extension-hijacking"
    npm test
    ;;
  all)
    echo "📍 Running all test suites in parallel"
    echo ""
    
    # Clean up old log files
    rm -f /tmp/test-*.log /tmp/test-*.pid
    
    # Start all test suites in parallel
    log_files=()
    
    log_files+=($(run_test_suite "global" "$PROJECT_ROOT/test"))
    sleep 2  # Small delay to stagger startup
    
    log_files+=($(run_test_suite "lab1" "$PROJECT_ROOT/labs/01-basic-magecart/test"))
    sleep 1
    
    log_files+=($(run_test_suite "lab2" "$PROJECT_ROOT/labs/02-dom-skimming/test"))
    sleep 1
    
    log_files+=($(run_test_suite "lab3" "$PROJECT_ROOT/labs/03-extension-hijacking"))
    
    # Wait for all tests to complete
    wait_for_tests "${log_files[@]}"
    ;;
  *)
    echo "❌ Invalid mode. Usage: $0 [all|global|1|2|3]"
    exit 1
    ;;
esac

echo ""
echo "✅ All tests completed!"

