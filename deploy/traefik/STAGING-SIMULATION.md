# Staging Simulation Testing

This document explains how to test Traefik route generation locally without deploying to Cloud Run.

## Problem

Deploying to Cloud Run takes ~4 minutes, making it slow to test route generation. We need a way to:
1. Test label-based route generation locally
2. Validate routes work correctly
3. Catch issues before deploying

## Solution: Docker Compose Staging Simulation

A `docker-compose.stg-simulation.yml` file that:
- Uses the same Traefik configuration as Cloud Run (file provider)
- Creates mock services with Traefik labels (matching Cloud Run format)
- Tests route generation from labels
- Validates routing works end-to-end

## Quick Start

```bash
# Start the simulation environment
docker-compose -f docker-compose.stg-simulation.yml up -d

# Wait for services to start
sleep 10

# Run tests
./deploy/traefik/test-stg-simulation.sh

# Clean up
docker-compose -f docker-compose.stg-simulation.yml down
```

## How It Works

### 1. Mock Services

The simulation creates mock services (nginx containers) with:
- Same Traefik labels as Cloud Run services
- Simple HTML/JSON responses for testing
- Network connectivity to Traefik

### 2. Route Generation

The test script:
1. Queries Docker services (instead of Cloud Run)
2. Extracts Traefik labels
3. Generates routes.yml (same format as Cloud Run)
4. Traefik file provider loads and applies routes

### 3. Route Testing

Tests validate:
- Routes are generated correctly
- Traefik can reach backend services
- Middlewares are applied
- Path matching works

## Architecture

```
┌─────────────────┐
│  Traefik        │  (file provider, no Docker socket)
│  (stg-sim)      │
└────────┬────────┘
         │ HTTP
         │
    ┌────┴────┬──────────┬──────────┐
    │         │          │          │
┌───▼───┐ ┌──▼───┐  ┌───▼───┐  ┌───▼───┐
│ Home  │ │ SEO  │  │ Lab 1 │  │ Lab 2 │
│ Index │ │      │  │       │  │       │
└───────┘ └──────┘  └───────┘  └───────┘
```

## Differences from Real Staging

| Aspect | Real Staging | Simulation |
|--------|--------------|------------|
| Service Discovery | gcloud query Cloud Run | docker inspect Docker services |
| Service URLs | Cloud Run URLs | Docker container IPs |
| Authentication | Identity tokens | None (local testing) |
| Network | Cloud Run networking | Docker bridge network |
| Refresh | Periodic (5s/5min) | Manual (test script) |

## Test Coverage

The simulation tests:
- ✅ Label extraction from services
- ✅ Router generation (rule, priority, entrypoints)
- ✅ Middleware application
- ✅ Service definition (URL, port)
- ✅ Path matching
- ✅ Multiple routers per service
- ✅ Static file routes (lab1-static, etc.)

## Limitations

- **No authentication**: Identity tokens not tested (services are local)
- **No cold starts**: Services are always running (no scale-to-zero)
- **Simplified responses**: Mock services return simple HTML/JSON
- **Docker-specific**: Uses Docker inspect instead of gcloud

## Extending Tests

Add more test cases in `test-stg-simulation.sh`:

```bash
# Test specific route
echo -n "Testing /custom/path → "
if curl -s http://localhost:8080/custom/path | grep -q "expected"; then
  echo "✅ PASS"
fi
```

## Integration with CI/CD

You can add this to GitHub Actions:

```yaml
- name: Test route generation
  run: |
    docker-compose -f docker-compose.stg-simulation.yml up -d
    sleep 10
    ./deploy/traefik/test-stg-simulation.sh
    docker-compose -f docker-compose.stg-simulation.yml down
```

## Troubleshooting

**Routes not working:**
```bash
# Check Traefik logs
docker logs e-skimming-labs-traefik-stg-sim

# Check generated routes
docker exec e-skimming-labs-traefik-stg-sim cat /etc/traefik/dynamic/routes.yml

# Check service labels
docker inspect mock-home-index | jq '.[0].Config.Labels'
```

**Services not found:**
```bash
# Verify services are running
docker ps | grep mock-

# Check network connectivity
docker exec e-skimming-labs-traefik-stg-sim ping mock-home-index
```

