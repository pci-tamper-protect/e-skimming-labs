# Route Generation Testing

This document explains how to test Traefik route generation locally using mock Cloud Run service data.

## Problem

Deploying to Cloud Run takes ~4 minutes, making it slow to test route generation. We need a way to:
1. Test label-based route generation logic
2. Validate routes are generated correctly
3. Catch issues before deploying

## Solution: Mock Cloud Run Data Test

The `test-route-generation.sh` script:
- Creates mock Cloud Run service JSON (simulating `gcloud run services describe`)
- Tests route generation logic directly
- Validates output YAML syntax and structure
- No Docker or Cloud Run required - pure logic testing

## Quick Start

```bash
# Run the test
./deploy/traefik/test-route-generation.sh
```

The test will:
1. Create mock service JSON files
2. Generate routes.yml from mock data
3. Validate routers, services, and YAML syntax
4. Clean up and report results

## What It Tests

### Test 1: Route Generation
- Extracts Traefik labels from mock service JSON
- Groups routers by name
- Generates router definitions with rules, priorities, entrypoints, middlewares

### Test 2: Router Validation
- Checks for expected routers:
  - `home-index`
  - `home-index-signin`
  - `home-seo`
  - `labs-analytics`
  - `lab1`
  - `lab1-static`

### Test 3: YAML Syntax
- Validates generated YAML is parseable
- Ensures structure matches Traefik's expected format

### Test 4: Retry Middleware
- Verifies `retry-cold-start@file` middleware is added to routers

## Mock Data Structure

The test uses mock JSON files that simulate `gcloud run services describe` output:

```json
{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "traefik.enable": "true",
          "traefik.http.routers.home-index.rule": "PathPrefix(`/`)",
          "traefik.http.routers.home-index.priority": "1",
          ...
        }
      }
    }
  },
  "status": {
    "url": "https://home-index-stg-1234567890.us-central1.run.app"
  }
}
```

## Expected Output

```
🧪 Testing Traefik Route Generation with Mock Cloud Run Data
==============================================================

📋 Test 1: Generate routes using mock Cloud Run data
📋 Test 2: Direct route generation from mock JSON
📋 Test 3: Validate generated routes.yml
  ✅ Found router: home-index
  ✅ Found router: home-index-signin
  ✅ Found router: home-seo
  ✅ Found router: labs-analytics
  ✅ Found router: lab1
  ✅ Found router: lab1-static
  ✅ Found 6/6 expected routers

📋 Test 4: Validate YAML syntax
  ✅ YAML syntax is valid

📋 Test 5: Validate retry middleware
  ✅ Retry middleware found 6 times

✅ Route generation tests passed!
```

## Integration with CI/CD

Add to GitHub Actions:

```yaml
- name: Test route generation
  run: |
    ./deploy/traefik/test-route-generation.sh
```

## Advantages Over Docker Compose Simulation

| Aspect | Mock Data Test | Docker Compose |
|--------|----------------|----------------|
| Speed | ⚡ Instant | 🐌 ~30 seconds |
| Dependencies | None (just bash/jq) | Docker, docker-compose |
| Coverage | Logic validation | End-to-end routing |
| Use Case | Pre-deploy validation | Full integration testing |

## Limitations

- **No actual routing**: Tests logic only, not live HTTP routing
- **No middleware execution**: Middlewares are validated but not executed
- **Simplified service discovery**: Uses mock JSON instead of real gcloud queries

## Extending Tests

Add more mock services:

```bash
# Add to test-route-generation.sh
cat > "$TEST_DIR/mock-services/new-service-stg.json" <<'EOF'
{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "traefik.enable": "true",
          "traefik.http.routers.new-service.rule": "PathPrefix(`/new`)",
          ...
        }
      }
    }
  },
  "status": {
    "url": "https://new-service-stg-1234567890.us-central1.run.app"
  }
}
EOF
```

## Troubleshooting

**Test fails with "YAML syntax is invalid":**
```bash
# Inspect generated routes
cat /tmp/traefik-route-test/routes.yml
```

**Router not found:**
- Check mock JSON has correct `traefik.enable=true`
- Verify router label keys match expected format
- Ensure router name is in `EXPECTED_ROUTERS` array

**Service not generated:**
- Check `traefik.http.services.<name>.loadbalancer.server.port` label exists
- Verify service URL is in `status.url`
