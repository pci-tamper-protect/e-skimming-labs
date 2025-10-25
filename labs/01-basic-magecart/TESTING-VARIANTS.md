# Testing E-Skimming Variants

This lab now supports testing different skimmer variants with automatic test
filtering.

## Quick Start

Use the helper script to test any variant:

```bash
./run-variant-tests.sh [variant]
```

Available variants:

- `base` - Standard checkout with basic skimmer (3 tests)
- `obfuscated-base64` - Base64 obfuscated skimmer (3 tests)
- `event-listener` - Event listener-based skimmer (4 tests)
- `websocket` - WebSocket exfiltration skimmer (5 tests)

## Examples

```bash
# Test the base variant
./run-variant-tests.sh base

# Test the event listener variant
./run-variant-tests.sh event-listener

# Test the obfuscated Base64 variant
./run-variant-tests.sh obfuscated-base64

# Test the WebSocket variant
./run-variant-tests.sh websocket
```

## How It Works

### 1. Docker Compose Configuration

The `docker-compose.yml` now accepts environment variables:

- `SKIMMER_VARIANT` - Specifies which variant is being tested
- `VARIANT_PATH` - Path to the variant's vulnerable-site directory

### 2. Playwright Configuration

The `test/playwright.config.js` automatically filters tests based on the
`SKIMMER_VARIANT` environment variable:

| Variant                  | Test File                        |
| ------------------------ | -------------------------------- |
| `base`                   | `checkout.spec.js`               |
| `obfuscated-base64`      | `obfuscated-base64.spec.js`      |
| `event-listener-variant` | `event-listener-variant.spec.js` |
| `websocket-exfil`        | `websocket-exfil.spec.js`        |

### 3. Environment Files

Pre-configured environment files are provided:

- `.env.base` - Base variant configuration
- `.env.obfuscated-base64` - Obfuscated variant configuration
- `.env.event-listener` - Event listener variant configuration
- `.env.websocket` - WebSocket variant configuration

## Manual Usage

If you prefer to run tests manually:

### Step 1: Set Environment Variables

```bash
export SKIMMER_VARIANT=event-listener-variant
export VARIANT_PATH=./variants/event-listener-variant/vulnerable-site
```

### Step 2: Start Docker Compose

```bash
docker-compose up -d
```

### Step 3: Run Tests

```bash
cd test
SKIMMER_VARIANT=event-listener-variant npx playwright test
```

## Using .env Files

You can also copy a variant-specific .env file:

```bash
# Use the event listener variant
cp .env.event-listener .env

# Start services
docker-compose up -d

# Run tests
cd test
npx playwright test
```

## Test Results

### Base Variant

- ✅ All 3 tests pass
- Tests basic form submission skimming
- Validates console logs and network requests

### Event Listener Variant

- ✅ 3 of 4 tests pass
- Tests real-time field monitoring
- Validates progressive data collection
- ⚠️ Mobile touch test requires additional configuration

### Obfuscated Base64 Variant

- Tests Base64 obfuscation patterns
- Validates deobfuscation and execution

### WebSocket Variant

- Tests WebSocket communication
- Validates HTTP fallback mechanism
- Tests reconnection logic

## Troubleshooting

### Services Not Starting

Check if ports are already in use:

```bash
lsof -i :8080
lsof -i :3000
```

Stop any conflicting services:

```bash
docker-compose down
kill <PID>
```

### Wrong Variant Being Tested

Ensure environment variables are set correctly:

```bash
echo $SKIMMER_VARIANT
echo $VARIANT_PATH
```

Restart with clean state:

```bash
docker-compose down
./run-variant-tests.sh [variant]
```

### Tests Failing

1. Verify services are running:

   ```bash
   curl http://localhost:8080
   curl http://localhost:3000
   ```

2. Check Docker logs:

   ```bash
   docker-compose logs
   ```

3. Run tests with verbose output:
   ```bash
   cd test
   SKIMMER_VARIANT=[variant] npx playwright test --reporter=list
   ```

## Architecture

```
labs/01-basic-magecart/
├── docker-compose.yml           # Supports SKIMMER_VARIANT & VARIANT_PATH
├── .env                         # Default configuration
├── .env.base                    # Base variant config
├── .env.event-listener          # Event listener config
├── .env.obfuscated-base64       # Obfuscated variant config
├── .env.websocket               # WebSocket variant config
├── run-variant-tests.sh         # Helper script
├── vulnerable-site/             # Base variant files
├── variants/
│   ├── event-listener-variant/
│   │   └── vulnerable-site/     # Event listener variant files
│   ├── obfuscated-base64/
│   │   └── vulnerable-site/     # Obfuscated variant files
│   └── websocket-exfil/
│       └── vulnerable-site/     # WebSocket variant files
└── test/
    ├── playwright.config.js     # Auto-filters tests by variant
    └── tests/
        ├── checkout.spec.js
        ├── event-listener-variant.spec.js
        ├── obfuscated-base64.spec.js
        └── websocket-exfil.spec.js
```

## Benefits

1. **Focused Testing** - Only runs tests relevant to the current variant
2. **Faster Test Execution** - Reduced test time by running only applicable
   tests
3. **Clear Results** - No false failures from testing wrong variants
4. **Easy Switching** - Simple one-command variant changes
5. **CI/CD Ready** - Environment variable-based configuration
