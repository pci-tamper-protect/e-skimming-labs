# Testing Guide

This guide covers testing E-Skimming Labs in different environments.

## Quick Reference

| Environment | Guide |
|-------------|-------|
| Local (sidecar) | [LOCAL_TESTING.md](./LOCAL_TESTING.md) |
| Staging | [STAGING_TESTING.md](./STAGING_TESTING.md) |

## Testing Modes

### Local Testing

Test against the local sidecar simulation or local Docker containers.

```bash
# Start local sidecar
docker compose -f docker-compose.sidecar-local.yml up -d

# Test routing
curl http://localhost:9090/
curl http://localhost:9090/lab1
curl http://localhost:9090/lab2
curl http://localhost:9090/lab3

# Check Traefik dashboard
open http://localhost:9091/dashboard/
```

[Full Guide →](./LOCAL_TESTING.md)

### Staging Testing

Test against deployed Cloud Run services.

```bash
# Start proxy
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082

# Test routing
curl http://127.0.0.1:8082/
curl http://127.0.0.1:8082/lab1
```

[Full Guide →](./STAGING_TESTING.md)

## Test Scripts

### Sidecar Local Test

```bash
./deploy/traefik/test-sidecar-local.sh
```

Tests:
- Service status
- Traefik readiness
- Route generation
- Endpoint accessibility

### Routing Test

```bash
./tests/test-traefik-routing.sh
```

Tests all routes return expected status codes.

## Common Test Commands

### Check Routes

```bash
# Via Traefik API
curl http://localhost:9091/api/http/routers | jq

# Check specific router
curl http://localhost:9091/api/http/routers | jq '.[] | select(.name | contains("lab1"))'
```

### Check Services

```bash
curl http://localhost:9091/api/http/services | jq
```

### Test with Verbose Output

```bash
curl -v http://localhost:9090/lab1
```

### Check Response Headers

```bash
curl -I http://localhost:9090/lab1
```

## Troubleshooting Tests

### 401 Unauthorized

Tokens expired. Restart provider:
```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### 404 Not Found

Route not configured. Check:
```bash
# Provider logs
docker compose -f docker-compose.sidecar-local.yml logs provider

# Generated routes
docker compose -f docker-compose.sidecar-local.yml exec traefik \
  cat /shared/traefik/dynamic/routes.yml
```

### 502 Bad Gateway

Backend service not responding. Check:
```bash
# Service logs
gcloud run services logs read SERVICE_NAME \
  --project=labs-stg \
  --region=us-central1 \
  --limit=50
```

## Next Steps

- [Local testing details](./LOCAL_TESTING.md)
- [Staging testing details](./STAGING_TESTING.md)
- [Troubleshooting](../troubleshooting/README.md)
