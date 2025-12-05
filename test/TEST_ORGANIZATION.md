# Test Organization Guide

This document explains how tests are organized and why certain tests are in specific locations.

## Test Structure Overview

### Global Tests (`test/e2e/`)

**Location:** `test/e2e/`

**Purpose:** Tests for shared components and global navigation that work across all labs.

**Tests:**
- `global-navigation.spec.js` - Tests navigation between home, MITRE, Threat Model, and labs
- `mitre-attack-matrix.spec.js` - Tests the MITRE ATT&CK Matrix page
- `threat-model.spec.js` - Tests the Threat Model page

**When they run:**
- When using `./test/run-tests-local.sh all` or `./test/run-tests-prd.sh all`
- When using `./test/run-global-tests.sh`

### Lab-Specific Tests

**Location:** `labs/{lab-number}/test/tests/`

**Purpose:** Tests for lab-specific functionality, including lab-specific navigation.

**Example - Lab 1:**
- `checkout.spec.js` - Tests Lab 1 checkout flow, skimmer functionality, **and Lab 1 writeup navigation**
- `event-listener-variant.spec.js` - Tests Lab 1 event listener variant
- `obfuscated-base64.spec.js` - Tests Lab 1 obfuscated variant
- `websocket-exfil.spec.js` - Tests Lab 1 WebSocket variant

**When they run:**
- When using `./test/run-tests-local.sh 1` (Lab 1 only)
- When using `./test/run-tests-local.sh all` (includes all labs)

## Why Navigation Tests Are in Different Places

### Global Navigation (`test/e2e/global-navigation.spec.js`)

Tests general navigation that applies to all labs:
- Home → MITRE → Home
- Home → Threat Model → Home
- Home → Lab 1 → C2 → Home
- Home → Lab 2 → C2 → Home
- Home → Lab 3 → C2 → Home

**These tests verify:**
- Navigation links work
- Back buttons work
- Pages load correctly
- Cross-lab navigation

### Lab-Specific Navigation (`labs/01-basic-magecart/test/tests/checkout.spec.js`)

Tests Lab 1 specific navigation:
- Lab 1 → Writeup → Lab 1

**Why it's in `checkout.spec.js`:**
- The writeup navigation is **Lab 1 specific** (each lab has its own writeup)
- It's part of the Lab 1 checkout flow test suite
- It tests Lab 1's writeup page functionality, not general navigation

**If you want all navigation tests together:**
You could move this test to `global-navigation.spec.js`, but it would need to be Lab 1 specific:
```javascript
test('should navigate Lab 1 to writeup page and back', async ({ page }) => {
  // Lab 1 specific test
})
```

## Running All Tests

### Complete Test Suite

```bash
# Run everything: global tests + all lab tests
./test/run-tests-local.sh all
```

This runs:
1. Global navigation tests (`test/e2e/global-navigation.spec.js`)
2. MITRE ATT&CK tests (`test/e2e/mitre-attack-matrix.spec.js`)
3. Threat Model tests (`test/e2e/threat-model.spec.js`)
4. Lab 1 tests (`labs/01-basic-magecart/test/tests/checkout.spec.js` + variants)
5. Lab 2 tests (`labs/02-dom-skimming/test/...`)
6. Lab 3 tests (`labs/03-extension-hijacking/...`)

### Individual Test Suites

```bash
# Only global tests
./test/run-global-tests.sh local

# Only Lab 1 tests (includes writeup navigation)
./test/run-tests-local.sh 1

# Only Lab 2 tests
./test/run-tests-local.sh 2
```

## Test Counts

When you run `./test/run-tests-local.sh all`, you should see:

**Global Tests:**
- `global-navigation.spec.js`: ~7 tests (navigation between pages)
- `mitre-attack-matrix.spec.js`: Multiple tests (MITRE page functionality)
- `threat-model.spec.js`: Multiple tests (Threat Model page functionality)

**Lab 1 Tests:**
- `checkout.spec.js`: 4 tests including:
  - Checkout flow
  - Console log capture
  - Network request to C2
  - **Writeup navigation** (Lab 1 specific)

**Lab 2 & Lab 3:** Their respective test counts

## Understanding Test Reports

When viewing test reports:

1. **Global navigation tests** appear under `test/e2e/global-navigation.spec.js`
2. **Lab 1 writeup navigation** appears under `labs/01-basic-magecart/test/tests/checkout.spec.js`

This is intentional - the writeup navigation is Lab 1 specific functionality, not general navigation.

## Moving Tests (If Needed)

If you want to move the Lab 1 writeup navigation test to `global-navigation.spec.js`:

1. Copy the test from `checkout.spec.js`:
```javascript
test('should navigate Lab 1 to writeup page and back', async ({ page }) => {
  // ... test code ...
})
```

2. Add it to `test/e2e/global-navigation.spec.js` in a Lab 1 specific describe block:
```javascript
test.describe('Lab 1 Specific Navigation', () => {
  test('should navigate to writeup page and back to lab', async ({ page }) => {
    // ... test code ...
  })
})
```

3. Remove it from `checkout.spec.js`

**However**, keeping it in `checkout.spec.js` is recommended because:
- It's Lab 1 specific functionality
- It's part of the Lab 1 test suite
- It keeps related tests together

