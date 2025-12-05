# E-Skimming Labs Testing - Quick Reference

## 🚀 Quick Commands

### Local Testing

```bash
# Start services
docker-compose up -d

# Run all tests
./test/run-tests-local.sh

# Run specific lab
./test/run-tests-local.sh 1      # Lab 1
./test/run-tests-local.sh lab2   # Lab 2
./test/run-tests-local.sh 3      # Lab 3
```

### Production Testing

```bash
# Run all tests against production
./test/run-tests-prd.sh

# Run specific lab
./test/run-tests-prd.sh 1
./test/run-tests-prd.sh lab2
./test/run-tests-prd.sh 3
```

### Custom/Staging Testing

```bash
# Test against custom deployment
./test/run-tests-custom.sh --base-url https://staging.example.com

# Test specific lab with custom URLs
./test/run-tests-custom.sh \
  --base-url https://staging.example.com \
  --lab1-url https://lab1.example.com \
  --lab1-c2-url https://lab1-c2.example.com \
  1
```

## 📍 Environment URLs

### Local (localhost)
- Home: `http://localhost:3000`
- Lab 1: `http://localhost:9001` / C2: `http://localhost:9002`
- Lab 2: `http://localhost:9003` / C2: `http://localhost:9004`
- Lab 3: `http://localhost:9005` / C2: `http://localhost:9006`

### Production
- Home: `https://labs.pcioasis.com`
- Lab 1: `https://lab-01-basic-magecart-prd-...`
- Lab 2: `https://lab-02-dom-skimming-prd-...`
- Lab 3: `https://lab-03-extension-hijacking-prd-...`

## 🔧 Environment Variables

```bash
# Set test environment
export TEST_ENV=local    # localhost (default)
export TEST_ENV=prd      # production
export TEST_ENV=custom   # custom deployment

# Custom environment URLs
export CUSTOM_BASE_URL=https://staging.example.com
export CUSTOM_LAB1_URL=https://lab1.example.com
export CUSTOM_LAB1_C2_URL=https://lab1-c2.example.com
```

## ⚡ Parallel Execution

```bash
# Run all test suites in parallel (fastest)
./test/run-tests-local-parallel.sh all

# Control worker count
PLAYWRIGHT_WORKERS=4 npm test

# Use all CPU cores (may overload system)
PLAYWRIGHT_WORKERS=100% npm test
```

## 🐛 Debugging

```bash
# Run with visible browser
npx playwright test --headed

# Run in debug mode
npx playwright test --debug

# Run with UI mode
npx playwright test --ui

# View test report
npx playwright show-report
```

## ✅ Verify Setup

```bash
# Check services are running (local)
docker-compose ps
curl http://localhost:3000/health

# Check production
curl https://labs.pcioasis.com/health

# Verify test environment config
node test/config/test-env.js
```

## 📚 Full Documentation

See [TESTING_GUIDE.md](./TESTING_GUIDE.md) for complete documentation.

