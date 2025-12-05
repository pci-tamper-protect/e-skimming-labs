# E-Skimming Labs Testing Guide

Complete guide for testing e-skimming-labs against local, staging, and production deployments.

## Quick Start

### Test Against Local Deployment

```bash
# Start local services
docker-compose up -d

# Run tests against localhost
./test/run-tests-local.sh        # All labs + global navigation tests
./test/run-tests-local.sh 1      # Lab 1 only (no global tests)
./test/run-tests-local.sh lab2   # Lab 2 only (no global tests)
./test/run-tests-local.sh 3      # Lab 3 only (no global tests)

# Run only global navigation tests
./test/run-global-tests.sh local
```

### Test Against Production

```bash
# Run tests against production (labs.pcioasis.com)
./test/run-tests-prd.sh          # All labs + global navigation tests
./test/run-tests-prd.sh 1        # Lab 1 only (no global tests)
./test/run-tests-prd.sh lab2     # Lab 2 only (no global tests)
./test/run-tests-prd.sh 3        # Lab 3 only (no global tests)

# Run only global navigation tests against production
./test/run-global-tests.sh prd
```

### Test Against Custom Remote Deployment

```bash
# Set custom base URL
export TEST_ENV=custom
export CUSTOM_BASE_URL=https://staging-labs.example.com

# Run tests
cd labs/01-basic-magecart/test
npm test
```

## Environments

### Local Environment (localhost)

**Services:**
- Home Index: `http://localhost:3000`
- Lab 1 Vulnerable: `http://localhost:9001`
- Lab 1 C2: `http://localhost:9002`
- Lab 2 Vulnerable: `http://localhost:9003`
- Lab 2 C2: `http://localhost:9004`
- Lab 3 Vulnerable: `http://localhost:9005`
- Lab 3 C2: `http://localhost:9006`

**Start Services:**
```bash
docker-compose up -d
```

**Verify Services:**
```bash
# Check all services are running
docker-compose ps

# Check specific service
curl http://localhost:3000/health
curl http://localhost:9001
```

### Production Environment

**Services:**
- Home Index: `https://labs.pcioasis.com`
- Lab 1: `https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app`
- Lab 2 Vulnerable: `https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app`
- Lab 2 C2: `https://lab-02-dom-skimming-c2-prd-mmwwcfi5za-uc.a.run.app`
- Lab 3 Vulnerable: `https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app`
- Lab 3 C2: `https://lab-03-extension-hijacking-c2-prd-mmwwcfi5za-uc.a.run.app`

**Prerequisites:**
- Production services must be deployed and running
- No local services needed

### Staging Environment (Custom)

To test against a staging or custom deployment, update `test/config/test-env.js`:

```javascript
const environments = {
  // ... existing environments ...
  staging: {
    homeIndex: 'https://staging-labs.example.com',
    lab1: {
      vulnerable: 'https://staging-lab1.example.com',
      c2: 'https://staging-lab1-c2.example.com',
      writeup: 'https://staging-labs.example.com/lab-01-writeup',
    },
    // ... other labs ...
  },
}
```

Then run:
```bash
TEST_ENV=staging ./test/run-tests-local.sh
```

## Testing Methods

### Method 1: Helper Scripts (Recommended)

**Local:**
```bash
./test/run-tests-local.sh [lab_number|all]
```

**Production:**
```bash
./test/run-tests-prd.sh [lab_number|all]
```

**Examples:**
```bash
./test/run-tests-local.sh 1      # Lab 1 against localhost
./test/run-tests-local.sh all    # All labs against localhost
./test/run-tests-prd.sh lab2     # Lab 2 against production
```

### Method 2: Environment Variables

**Set TEST_ENV before running tests:**
```bash
# Local (default)
TEST_ENV=local npm test

# Production
TEST_ENV=prd npm test

# Staging (if configured)
TEST_ENV=staging npm test
```

### Method 3: Direct npm Commands

**From individual lab test directories:**
```bash
cd labs/01-basic-magecart/test
npm test                    # Uses local environment (default)
TEST_ENV=prd npm test       # Uses production environment
```

## Test Structure

### Global Tests (test/e2e/)

Tests for shared components and global navigation:

```
test/
├── e2e/
│   ├── global-navigation.spec.js    # Global navigation between pages
│   ├── mitre-attack-matrix.spec.js  # MITRE ATT&CK Matrix page tests
│   └── threat-model.spec.js         # Threat Model page tests
└── config/
    └── test-env.js                   # Environment configuration
```

**Note:** These tests run when you use `./test/run-tests-local.sh all` or `./test/run-global-tests.sh`

### Lab-Specific Tests

Each lab has its own test directory with lab-specific functionality:

```
labs/
├── 01-basic-magecart/
│   └── test/
│       └── tests/
│           ├── checkout.spec.js              # Lab 1 checkout flow (includes Lab 1 writeup navigation)
│           ├── event-listener-variant.spec.js
│           ├── obfuscated-base64.spec.js
│           └── websocket-exfil.spec.js
├── 02-dom-skimming/
│   └── test/
│       └── test-dom-skimming.spec.js
└── 03-extension-hijacking/
    └── test-automation.js
```

**Note:** Lab-specific tests include navigation tests for that lab's specific features (e.g., Lab 1's writeup page navigation is in `checkout.spec.js` because it's Lab 1 specific).

## Configuration

### Test Environment Configuration

The `test/config/test-env.js` file manages environment URLs:

```javascript
const environments = {
  local: {
    homeIndex: 'http://localhost:3000',
    lab1: { vulnerable: 'http://localhost:9001', c2: 'http://localhost:9002' },
    // ...
  },
  prd: {
    homeIndex: 'https://labs.pcioasis.com',
    lab1: { vulnerable: 'https://lab-01-...', c2: 'https://lab-01-...' },
    // ...
  },
}
```

### Adding a New Environment

1. Add environment to `test/config/test-env.js`:
```javascript
const environments = {
  // ... existing ...
  staging: {
    homeIndex: 'https://staging.example.com',
    lab1: { vulnerable: '...', c2: '...' },
    // ...
  },
}
```

2. Use it:
```bash
TEST_ENV=staging npm test
```

## Running Specific Tests

### By Lab

```bash
# Lab 1 only
./test/run-tests-local.sh 1

# Lab 2 only
./test/run-tests-local.sh lab2

# Lab 3 only
./test/run-tests-local.sh 3
```

### By Test File

```bash
cd labs/01-basic-magecart/test
npx playwright test test-checkout.spec.js
```

### By Test Name Pattern

```bash
cd labs/01-basic-magecart/test
npx playwright test --grep "checkout"
```

## Debugging Tests

### Run in Headed Mode (See Browser)

```bash
cd labs/01-basic-magecart/test
npx playwright test --headed
```

### Run in Debug Mode

```bash
cd labs/01-basic-magecart/test
npx playwright test --debug
```

### Run with UI Mode

```bash
cd labs/01-basic-magecart/test
npx playwright test --ui
```

### Run with Trace

```bash
cd labs/01-basic-magecart/test
npx playwright test --trace on
```

### View Test Report

```bash
cd labs/01-basic-magecart/test
npx playwright show-report
```

## Continuous Integration

### GitHub Actions

Tests can run in CI against production:

```yaml
- name: Run tests against production
  run: |
    export TEST_ENV=prd
    ./test/run-tests-prd.sh all
  env:
    TEST_ENV: prd
```

### Pre-commit Testing

Test locally before committing:

```bash
# Quick test against local
./test/run-tests-local.sh 1

# Full test against production
./test/run-tests-prd.sh all
```

## Troubleshooting

### Services Not Running (Local)

**Problem:** Tests fail with connection errors

**Solution:**
```bash
# Check services
docker-compose ps

# Start services
docker-compose up -d

# Check logs
docker-compose logs lab1-vulnerable-site
```

### Production Services Unavailable

**Problem:** Tests fail against production

**Solution:**
1. Verify production services are deployed:
   ```bash
   curl https://labs.pcioasis.com/health
   ```

2. Check Cloud Run service status:
   ```bash
   gcloud run services list --project=labs-prd
   ```

3. Verify URLs in `test/config/test-env.js` are correct

### Environment Variable Not Set

**Problem:** Tests use wrong environment

**Solution:**
```bash
# Explicitly set environment
export TEST_ENV=prd
npm test

# Or use helper script
./test/run-tests-prd.sh
```

### Port Conflicts (Local)

**Problem:** Ports already in use

**Solution:**
```bash
# Find process using port
lsof -i :3000
lsof -i :9001

# Stop conflicting services or change ports in docker-compose.yml
```

## Best Practices

### 1. Test Locally First

Always test against localhost before testing production:
```bash
./test/run-tests-local.sh all
```

### 2. Use Helper Scripts

Prefer helper scripts over manual commands:
```bash
# ✅ Good
./test/run-tests-prd.sh 1

# ❌ Avoid
cd labs/01-basic-magecart/test && TEST_ENV=prd npm test
```

### 3. Verify Environment

Check which environment tests will use:
```bash
node test/config/test-env.js
```

### 4. Test One Lab at a Time

When debugging, test individual labs:
```bash
./test/run-tests-local.sh 1  # Test Lab 1 only
```

### 5. Check Service Health

Before running tests, verify services are healthy:
```bash
# Local
curl http://localhost:3000/health

# Production
curl https://labs.pcioasis.com/health
```

## Advanced Usage

### Custom Base URL

For testing against a completely custom deployment:

```bash
# Set custom URLs via environment variables
export TEST_ENV=custom
export CUSTOM_HOME_URL=https://custom.example.com
export CUSTOM_LAB1_URL=https://custom-lab1.example.com

# Update test-env.js to read these variables
```

### Parallel Testing

Tests are now configured to run in parallel automatically. Each test suite uses up to 4 workers (50% of CPU cores).

**Within a test suite (automatic):**
- Tests within the same file run in parallel
- Multiple test files run in parallel
- Uses up to 4 workers by default (configurable)

**Run test suites in parallel (faster overall):**
```bash
# Run all test suites in parallel (global + all labs simultaneously)
./test/run-tests-local-parallel.sh all

# This is faster but:
# - Uses more CPU/memory
# - Output may be interleaved
# - Harder to debug failures
```

**Manual worker control:**
```bash
# Override worker count for a specific test run
cd labs/01-basic-magecart/test
npx playwright test --workers=4

# Use all CPU cores (not recommended - may overload system)
npx playwright test --workers=100%
```

### Test Filtering

Run only specific tests:

```bash
# By tag
npx playwright test --grep @smoke

# By file pattern
npx playwright test test-checkout.spec.js
```

### CI-Specific Configuration

For CI environments, use different timeouts:

```bash
# In CI, use longer timeouts
export CI=true
npx playwright test --timeout=60000
```

## Reference

### Environment URLs

See `test/config/test-env.js` for complete URL mappings.

### Test Scripts

- `./test/run-tests-local.sh` - Run against localhost
- `./test/run-tests-prd.sh` - Run against production
- `./test/test-local-routing.sh` - Test routing configuration

### Documentation

- `test/README.md` - Test suite overview
- `test/ENVIRONMENT_TESTING.md` - Environment testing details
- `docs/SETUP.md` - Setup instructions

