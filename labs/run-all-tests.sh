#!/bin/bash

# E-Skimming Labs - Run All Tests
# This script runs all Playwright tests for all labs and generates a summary report

set -e

echo "🧪 E-Skimming Labs - Running All Tests"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
PENDING_TESTS=0

# Lab 1 Tests
echo "📦 Lab 1: Basic Magecart Attack"
echo "--------------------------------"
cd labs/01-basic-magecart/test
if [ -f "package.json" ]; then
  npm test 2>&1 | tee ../../../test-results-lab1.txt
  LAB1_STATUS=$?
  if [ $LAB1_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Lab 1 tests passed${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo -e "${RED}❌ Lab 1 tests failed${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
else
  echo -e "${YELLOW}⚠️  Lab 1 tests not configured${NC}"
  PENDING_TESTS=$((PENDING_TESTS + 1))
fi
cd ../../..

echo ""
echo "📦 Lab 2: DOM-Based Skimming"
echo "--------------------------------"
cd labs/02-dom-skimming
if [ -f "playwright.config.js" ]; then
  npx playwright test 2>&1 | tee ../test-results-lab2.txt
  LAB2_STATUS=$?
  if [ $LAB2_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Lab 2 tests passed${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo -e "${RED}❌ Lab 2 tests failed${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
else
  echo -e "${YELLOW}⚠️  Lab 2 tests not configured${NC}"
  PENDING_TESTS=$((PENDING_TESTS + 1))
fi
cd ..

echo ""
echo "📦 Lab 3: Extension Hijacking"
echo "--------------------------------"
cd labs/03-extension-hijacking/test
if [ -f "cc-exfiltration.spec.js" ]; then
  npx playwright test 2>&1 | tee ../../test-results-lab3.txt
  LAB3_STATUS=$?
  if [ $LAB3_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Lab 3 tests passed${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo -e "${RED}❌ Lab 3 tests failed${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
else
  echo -e "${YELLOW}⚠️  Lab 3 tests not configured${NC}"
  PENDING_TESTS=$((PENDING_TESTS + 1))
fi
cd ../../..

echo ""
echo "========================================"
echo "📊 Test Summary"
echo "========================================"
echo -e "Total Labs Tested: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
echo -e "${YELLOW}Pending: ${PENDING_TESTS}${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
  echo -e "${GREEN}✅ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some tests failed${NC}"
  exit 1
fi


