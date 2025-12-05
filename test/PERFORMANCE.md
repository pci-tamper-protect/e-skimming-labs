# Test Performance Optimization

This document explains how tests are parallelized and how to optimize test execution speed.

## Current Parallelization

### Within Test Suites (Automatic)

Each test suite now uses **up to 4 workers** by default (50% of CPU cores):
- Tests within the same file run in parallel
- Multiple test files run in parallel
- Each worker runs tests in a separate browser instance

**Configuration:**
- Global tests: 4 workers (was 2)
- Lab 1 tests: 4 workers (was CPU count)
- Lab 2 tests: 4 workers (was CPU count)
- Lab 3 tests: 4 workers (was CPU count)

### Across Test Suites (Optional)

You can run multiple test suites in parallel:

```bash
# Run all suites simultaneously (fastest)
./test/run-tests-local-parallel.sh all
```

**Trade-offs:**
- ✅ **Faster**: All suites run simultaneously
- ⚠️ **More resources**: Uses more CPU/memory
- ⚠️ **Interleaved output**: Harder to read logs
- ⚠️ **Harder debugging**: Failures may be less clear

## Performance Improvements

### Before Optimization

- Global tests: 2 workers
- Lab tests: Sequential execution
- Total time: ~5-10 minutes for full suite

### After Optimization

- Global tests: 4 workers
- Lab tests: 4 workers each
- Parallel suites option available
- Total time: ~2-4 minutes for full suite (with parallel suites)

## Controlling Workers

### Environment Variable

```bash
# Set worker count for a test run
PLAYWRIGHT_WORKERS=4 npm test

# Use all CPU cores (not recommended)
PLAYWRIGHT_WORKERS=100% npm test

# Use specific number
PLAYWRIGHT_WORKERS=8 npm test
```

### Command Line Override

```bash
# Override workers for specific run
npx playwright test --workers=4

# Use percentage of CPU cores
npx playwright test --workers=50%
```

### In Config Files

Workers are configured in each `playwright.config.js`:
- Default: 50% of CPU cores, max 4
- CI: 1 worker (sequential)
- Override: `PLAYWRIGHT_WORKERS` environment variable

## Best Practices

### For Development

```bash
# Use default parallelization (good balance)
./test/run-tests-local.sh all
```

### For Fast Feedback

```bash
# Run suites in parallel (fastest)
./test/run-tests-local-parallel.sh all
```

### For CI/CD

```bash
# Sequential execution (more reliable)
export CI=true
./test/run-tests-local.sh all
```

### For Debugging

```bash
# Single worker (easier to debug)
PLAYWRIGHT_WORKERS=1 npm test
```

## Resource Usage

### Default Configuration (4 workers)

- **CPU**: ~50% utilization
- **Memory**: ~2-4GB per worker
- **Browser instances**: 4 simultaneous

### Parallel Suites (all suites at once)

- **CPU**: ~80-100% utilization
- **Memory**: ~8-16GB total
- **Browser instances**: 12+ simultaneous

### Recommendations

- **Development**: Use default (4 workers)
- **Fast runs**: Use parallel suites script
- **CI/CD**: Use sequential (CI=true)
- **Debugging**: Use 1 worker

## Monitoring Performance

### Check Test Duration

```bash
# Run with timing
time ./test/run-tests-local.sh all

# Or check Playwright report
npx playwright show-report
```

### Check Resource Usage

```bash
# Monitor CPU/memory while tests run
top
# or
htop
```

## Troubleshooting

### Tests Fail with More Workers

**Problem:** Tests fail when using more workers

**Solution:**
- Check for shared state between tests
- Ensure tests are truly independent
- Use `test.describe.serial()` for tests that must run sequentially

### System Overload

**Problem:** System becomes unresponsive with parallel execution

**Solution:**
```bash
# Reduce workers
PLAYWRIGHT_WORKERS=2 npm test

# Or run suites sequentially
./test/run-tests-local.sh all  # Instead of parallel version
```

### Flaky Tests

**Problem:** Tests pass/fail randomly with parallel execution

**Solution:**
- Check for race conditions
- Ensure proper test isolation
- Use `test.describe.serial()` if needed
- Check for shared resources (files, databases, etc.)

## Future Optimizations

Potential further improvements:

1. **Test sharding**: Split large test files across multiple workers
2. **Selective execution**: Only run changed tests
3. **Caching**: Cache test results for unchanged code
4. **Test prioritization**: Run faster tests first
5. **Distributed testing**: Run tests across multiple machines

