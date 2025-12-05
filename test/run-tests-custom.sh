#!/bin/bash
# Run Playwright tests against a custom/staging deployment
#
# Usage:
#   ./test/run-tests-custom.sh --base-url https://staging.example.com [lab_number]
#   ./test/run-tests-custom.sh --base-url https://staging.example.com --lab1-url https://lab1.example.com
#
# Examples:
#   ./test/run-tests-custom.sh --base-url https://staging-labs.example.com
#   ./test/run-tests-custom.sh --base-url https://staging-labs.example.com 1
#   ./test/run-tests-custom.sh --base-url https://staging-labs.example.com --lab1-url https://lab1.example.com

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BASE_URL=""
LAB1_URL=""
LAB1_C2_URL=""
LAB2_URL=""
LAB2_C2_URL=""
LAB3_URL=""
LAB3_C2_URL=""
LAB="all"

show_help() {
    cat << EOF
Run tests against a custom/staging deployment.

Usage:
  $0 [OPTIONS] [lab_number]

Options:
  --base-url URL              Base URL for the deployment (required)
  --lab1-url URL              Lab 1 vulnerable site URL
  --lab1-c2-url URL          Lab 1 C2 server URL
  --lab2-url URL              Lab 2 vulnerable site URL
  --lab2-c2-url URL          Lab 2 C2 server URL
  --lab3-url URL              Lab 3 vulnerable site URL
  --lab3-c2-url URL          Lab 3 C2 server URL
  -h, --help                  Show this help message

Arguments:
  lab_number                  Lab to test (1, 2, 3, or 'all', default: all)

Examples:
  # Test all labs against staging
  $0 --base-url https://staging-labs.example.com

  # Test only Lab 1
  $0 --base-url https://staging-labs.example.com 1

  # Test with custom Lab 1 URLs
  $0 --base-url https://staging-labs.example.com \\
     --lab1-url https://lab1.example.com \\
     --lab1-c2-url https://lab1-c2.example.com

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --lab1-url)
            LAB1_URL="$2"
            shift 2
            ;;
        --lab1-c2-url)
            LAB1_C2_URL="$2"
            shift 2
            ;;
        --lab2-url)
            LAB2_URL="$2"
            shift 2
            ;;
        --lab2-c2-url)
            LAB2_C2_URL="$2"
            shift 2
            ;;
        --lab3-url)
            LAB3_URL="$2"
            shift 2
            ;;
        --lab3-c2-url)
            LAB3_C2_URL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        1|lab1|2|lab2|3|lab3|all)
            LAB="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate base URL
if [ -z "$BASE_URL" ]; then
    echo "Error: --base-url is required"
    show_help
    exit 1
fi

echo -e "${GREEN}🧪 Running tests against CUSTOM deployment${NC}"
echo -e "${GREEN}📍 Base URL: ${BASE_URL}${NC}"
echo ""

# Set environment variables
export TEST_ENV=custom
export CUSTOM_BASE_URL="$BASE_URL"

if [ -n "$LAB1_URL" ]; then
    export CUSTOM_LAB1_URL="$LAB1_URL"
fi

if [ -n "$LAB1_C2_URL" ]; then
    export CUSTOM_LAB1_C2_URL="$LAB1_C2_URL"
fi

if [ -n "$LAB2_URL" ]; then
    export CUSTOM_LAB2_URL="$LAB2_URL"
fi

if [ -n "$LAB2_C2_URL" ]; then
    export CUSTOM_LAB2_C2_URL="$LAB2_C2_URL"
fi

if [ -n "$LAB3_URL" ]; then
    export CUSTOM_LAB3_URL="$LAB3_URL"
fi

if [ -n "$LAB3_C2_URL" ]; then
    export CUSTOM_LAB3_C2_URL="$LAB3_C2_URL"
fi

# Show configuration
echo "Configuration:"
echo "  Base URL: $BASE_URL"
[ -n "$LAB1_URL" ] && echo "  Lab 1 URL: $LAB1_URL"
[ -n "$LAB1_C2_URL" ] && echo "  Lab 1 C2 URL: $LAB1_C2_URL"
[ -n "$LAB2_URL" ] && echo "  Lab 2 URL: $LAB2_URL"
[ -n "$LAB2_C2_URL" ] && echo "  Lab 2 C2 URL: $LAB2_C2_URL"
[ -n "$LAB3_URL" ] && echo "  Lab 3 URL: $LAB3_URL"
[ -n "$LAB3_C2_URL" ] && echo "  Lab 3 C2 URL: $LAB3_C2_URL"
echo ""

# Run tests
case $LAB in
    1|lab1)
        echo "📍 Testing Lab 1: Basic Magecart"
        cd labs/01-basic-magecart/test
        npm test
        ;;
    2|lab2)
        echo "📍 Testing Lab 2: DOM Skimming"
        cd labs/02-dom-skimming/test
        npm test
        ;;
    3|lab3)
        echo "📍 Testing Lab 3: Extension Hijacking"
        cd labs/03-extension-hijacking
        npm test
        ;;
    all)
        echo "📍 Testing all labs"
        echo ""
        echo "▶️  Lab 1: Basic Magecart"
        cd labs/01-basic-magecart/test
        npm test
        cd ../../..

        echo ""
        echo "▶️  Lab 2: DOM Skimming"
        cd labs/02-dom-skimming/test
        npm test
        cd ../../..

        echo ""
        echo "▶️  Lab 3: Extension Hijacking"
        cd labs/03-extension-hijacking
        npm test
        cd ../..
        ;;
    *)
        echo "❌ Invalid lab number. Usage: $0 [1|2|3|all]"
        exit 1
        ;;
esac

echo ""
echo "✅ Tests completed!"

