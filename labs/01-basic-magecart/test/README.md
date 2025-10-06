# E-Skimming Lab - Automated Testing

This directory contains Playwright tests for automated checkout submission testing.

## ⚠️ Development Only

These tests are for **development and debugging purposes only**. They should NOT be included in production deployments.

## Setup

1. Ensure the lab is running:
   ```bash
   docker-compose up -d
   ```

2. Install test dependencies:
   ```bash
   cd test
   npm install
   ```

## Running Tests

### Quick Test (from lab root):
```bash
./test-checkout.sh
```

### Manual Test Commands:
```bash
cd test

# Run all checkout tests
npm test

# Run with browser visible
npm run test:headed

# Debug mode (step through)
npm run test:debug

# Interactive UI mode
npm run test:ui
```

## What the Tests Do

1. **Checkout Flow Test**: Fills out the checkout form with valid test data and submits it
2. **Console Logging**: Captures and displays all skimmer logs from the browser console
3. **Network Monitoring**: Monitors requests to the C2 server (`/collect` endpoint)
4. **Data Verification**: Checks that data was successfully captured

## Test Data Used

- **Card Numbers**: Valid Luhn-checked test numbers (4532123456789010, etc.)
- **Personal Info**: Fake test data (John Doe, test addresses, etc.)
- **Never uses real payment information**

## Debugging

The tests provide detailed logging including:
- All skimmer console messages
- Network requests to C2 server
- Response statuses and headers
- Request payload data

Check the test output for detailed debugging information about the data flow.

## Files

- `package.json` - Dependencies and scripts
- `playwright.config.js` - Test configuration
- `tests/checkout.spec.js` - Main test suite
- `../test-checkout.sh` - Quick run script