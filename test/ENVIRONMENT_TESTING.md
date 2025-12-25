# E-Skimming Labs - Environment Testing Guide

This guide explains how to run Playwright tests against different environments (localhost vs production).

## Environments

### Local Environment (localhost)
- **Home Index**: `http://localhost:3000`
- **Lab 1 Vulnerable Site**: `http://localhost:9001`
- **Lab 1 C2 Server**: `http://localhost:9002`
- **Lab 2 Vulnerable Site**: `http://localhost:9003`
- **Lab 2 C2 Server**: `http://localhost:9004`
- **Lab 3 Vulnerable Site**: `http://localhost:9005`
- **Lab 3 C2 Server**: `http://localhost:9006`

### Production Environment (labs.pcioasis.com)
- **Home Index**: `https://labs.pcioasis.com`
- **Lab 1**: Cloud Run endpoints
- **Lab 2**: Cloud Run endpoints
- **Lab 3**: Cloud Run endpoints

See `test/config/test-env.js` for exact Cloud Run URLs.

## Running Tests

### Option 1: Using Helper Scripts (Recommended)

Run tests against **localhost**:
```bash
# From project root
./test/run-tests-local.sh        # Run all labs
./test/run-tests-local.sh 1      # Run only Lab 1
./test/run-tests-local.sh lab2   # Run only Lab 2
```

Run tests against **production**:
```bash
# From project root
./test/run-tests-prd.sh          # Run all labs
./test/run-tests-prd.sh 1        # Run only Lab 1
./test/run-tests-prd.sh lab2     # Run only Lab 2
```

### Option 2: Using Environment Variables

Set the `TEST_ENV` variable before running tests:

```bash
# Test against localhost (default)
cd labs/01-basic-magecart/test
TEST_ENV=local npm test

# Test against production
cd labs/01-basic-magecart/test
TEST_ENV=prd npm test
```

### Option 3: Direct npm Commands

If `TEST_ENV` is not set, it defaults to `local`:

```bash
# From any lab's test directory
npm test                    # Uses local environment
TEST_ENV=prd npm test       # Uses production environment
```

## Configuration Details

### Test Environment Configuration (`test/config/test-env.js`)

The `test-env.js` module provides:
- Environment-specific URLs for all services
- Helper functions for getting C2 endpoints
- Automatic environment detection and validation

Example usage in tests:
```javascript
const { getC2ApiEndpoint, getC2CollectEndpoint, TEST_ENV } = require('../../../../test/config/test-env.js')

const c2ApiUrl = getC2ApiEndpoint(1)  // Lab 1 C2 API
const c2CollectUrl = getC2CollectEndpoint(1)  // Lab 1 C2 collect endpoint
```

### Playwright Configuration Updates

Each lab's `playwright.config.js` has been updated to:
- Load environment URLs from the shared configuration
- Adjust timeouts based on environment (longer for production)
- Skip starting local web server when testing against production
- Set appropriate base URLs for navigation

## Key Differences Between Environments

### Local (localhost)
- ✅ Automatically starts Docker containers via `webServer` config
- ✅ Fast response times (lower timeouts: 8s)
- ✅ Direct port access (e.g., `:9001`, `:9002`)
- ⚠️  Requires Docker Compose to be running

### Production (labs.pcioasis.com)
- ✅ Tests real production deployment
- ✅ Cloud Run URLs
- ⚠️  Slower response times (higher timeouts: 30s)
- ⚠️  Network latency considerations
- ⚠️  No automatic service startup

## Troubleshooting

### Tests Fail Against Production

**Problem**: Tests timeout or fail with network errors

**Solutions**:
1. Verify production services are running and accessible
2. Check Cloud Run service URLs in `test/config/test-env.js`
3. Ensure you have network connectivity to Cloud Run endpoints
4. Review test timeouts - production needs longer timeouts

### Tests Fail Against Localhost

**Problem**: Cannot connect to localhost services

**Solutions**:
1. Start Docker services: `docker-compose up`
2. Verify services are running: `docker-compose ps`
3. Check port availability: `lsof -i :9001` (or appropriate port)
4. Ensure services are healthy: `docker-compose logs`

### Environment Not Recognized

**Problem**: Error: `Invalid TEST_ENV: xyz`

**Solution**:
Set `TEST_ENV` to one of the valid values: `local` or `prd`

```bash
# Correct usage
TEST_ENV=local npm test
TEST_ENV=prd npm test

# Invalid - will throw error
TEST_ENV=staging npm test  # staging not configured yet
```

## Staging Environment

Staging environment (`stg`) is fully configured and ready to use!

### Running Tests Against Staging

```bash
# Set environment variable
export TEST_ENV=stg

# Run all tests
cd test
npm test

# Or run specific test suites
npx playwright test e2e/global-navigation.spec.js
npx playwright test e2e/auth-stg.spec.js
```

### Staging Setup

For complete staging environment documentation, see:
- **[docs/STAGING.md](../docs/STAGING.md)** - Complete staging guide (setup, testing, E2E)
- **[test/AUTH_SETUP.md](AUTH_SETUP.md)** - E2E test authentication setup

**Quick Notes:**
- Staging URL: `https://labs.stg.pcioasis.com`
- Requires Google IAM authentication for browser access
- Use proxy for development: `gcloud run services proxy traefik-stg --region=us-central1 --project=labs-stg --port=8081`
- **Important:** Restart proxy after deploying changes to Traefik or home-index-service

### Adding New Environments

To add a new environment (e.g., `dev`):

1. Edit `test/config/test-env.js`
2. Add new environment configuration:
```javascript
const environments = {
  local: { /* ... */ },
  stg: { /* ... */ },
  prd: { /* ... */ },
  dev: {
    homeIndex: 'https://labs.dev.pcioasis.com',
    lab1: {
      vulnerable: 'https://lab-01-dev-...',
      c2: 'https://lab-01-c2-dev-...',
    },
    // ... other labs
  }
}
```
3. Create corresponding test script: `test/run-tests-dev.sh`
4. Update this documentation

## CI/CD Integration

For GitHub Actions or other CI/CD pipelines:

```yaml
- name: Run tests against production
  run: TEST_ENV=prd ./test/run-tests-prd.sh
  env:
    TEST_ENV: prd
```

## Architecture

```
test/
├── config/
│   └── test-env.js          # Shared environment configuration
├── run-tests-local.sh       # Helper script for localhost testing
├── run-tests-prd.sh         # Helper script for production testing
└── ENVIRONMENT_TESTING.md   # This file

labs/
├── 01-basic-magecart/
│   └── test/
│       ├── playwright.config.js   # ✅ Updated to use test-env.js
│       └── tests/
│           └── checkout.spec.js   # ✅ Updated to use environment URLs
├── 02-dom-skimming/
│   └── test/
│       ├── playwright.config.js   # ⚠️  Needs updating
│       └── tests/
└── 03-extension-hijacking/
    └── playwright.config.js       # ⚠️  Needs updating
```

## Current Status

### Lab 1: Basic Magecart ✅
- ✅ Playwright config updated
- ✅ Test files updated to use environment URLs
- ✅ Helper scripts created
- ✅ Documentation added

### Lab 2: DOM Skimming ⚠️
- ⚠️  Needs Playwright config update
- ⚠️  Needs test file updates

### Lab 3: Extension Hijacking ⚠️
- ⚠️  Needs Playwright config update
- ⚠️  Needs test file updates

## Next Steps

To complete the environment testing setup:

1. Update Lab 2 Playwright config and tests
2. Update Lab 3 Playwright config and tests
3. Add staging environment configuration (optional)
4. Test against production to verify Cloud Run URLs
5. Integrate with CI/CD pipeline

## Examples

### Running Lab 1 Tests Against Production

```bash
# Option 1: Helper script
./test/run-tests-prd.sh 1

# Option 2: Environment variable
cd labs/01-basic-magecart/test
TEST_ENV=prd npm test

# Option 3: Inline
TEST_ENV=prd npm test --prefix labs/01-basic-magecart/test
```

### Verifying Configuration

```bash
# Check what environment will be used
cd labs/01-basic-magecart/test
node -e "const {TEST_ENV, currentEnv} = require('../../../test/config/test-env'); console.log('Environment:', TEST_ENV); console.log('URLs:', currentEnv.lab1)"
```

### Running Specific Tests

```bash
# Run only the main checkout test against production
cd labs/01-basic-magecart/test
TEST_ENV=prd npx playwright test checkout.spec.js -g "should complete checkout"
```
