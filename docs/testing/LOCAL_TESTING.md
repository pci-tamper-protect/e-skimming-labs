# Local Testing

Testing E-Skimming Labs in the local environment.

## Prerequisites

Start the local sidecar simulation:

```bash
docker compose -f docker-compose.sidecar-local.yml up -d
```

## Quick Tests

### Health Check

```bash
curl http://localhost:9090/ping
# Expected: OK
```

### Home Page

```bash
curl -s http://localhost:9090/ | head -20
# Expected: HTML content
```

### Lab Routes

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/lab1
# Expected: 200

curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/lab2
# Expected: 200

curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/lab3
# Expected: 200
```

### C2 Routes

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/lab1/c2
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/lab2/c2
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/lab3/extension
```

## Automated Test Script

```bash
./deploy/traefik/test-sidecar-local.sh
```

### What It Tests

1. **Service Status** - All containers are running
2. **Traefik Readiness** - Health check responds
3. **Provider Route Generation** - routes.yml is created
4. **Shared Volume** - Both containers can access routes
5. **Traefik Endpoints** - `/ping`, `/api/rawdata`, `/metrics`
6. **Dashboard Service** - UI and API proxy work
7. **Provider Logs** - Route generation activity
8. **Traefik Logs** - Configuration loaded
9. **Route Discovery** - Application routes found
10. **Configuration Validation** - Config files exist

## Traefik Dashboard

Access the dashboard to inspect routes:

```bash
open http://localhost:9091/dashboard/
```

### Check Routers

```bash
curl http://localhost:9091/api/http/routers | jq
```

### Check Services

```bash
curl http://localhost:9091/api/http/services | jq
```

### Check Middlewares

```bash
curl http://localhost:9091/api/http/middlewares | jq
```

## Debugging

### View Logs

```bash
# All logs
docker compose -f docker-compose.sidecar-local.yml logs -f

# Provider only
docker compose -f docker-compose.sidecar-local.yml logs -f provider

# Traefik only
docker compose -f docker-compose.sidecar-local.yml logs -f traefik
```

### Check Generated Routes

```bash
docker compose -f docker-compose.sidecar-local.yml exec traefik \
  cat /shared/traefik/dynamic/routes.yml
```

### Check Router Status

```bash
curl -s http://localhost:9091/api/http/routers | \
  jq '.[] | {name: .name, status: .status, rule: .rule}'
```

### Test Specific Route

```bash
curl -v http://localhost:9090/lab1
```

## Common Issues

### 401 Unauthorized

Tokens expired. Restart provider:
```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### 404 Not Found

Route not configured. Check:
1. Provider logs for errors
2. Generated routes.yml
3. Router status in dashboard

### Lab Shows Wrong Content

Service needs redeployment:
```bash
./deploy/deploy-labs.sh stg 02 --force-rebuild
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### "invalid_grant" Error

Refresh gcloud credentials:
```bash
gcloud auth application-default login
docker compose -f docker-compose.sidecar-local.yml restart provider
```

## Browser Testing

1. Open http://localhost:9090
2. Click through each lab
3. Verify navigation works (back/home buttons)
4. Check C2 dashboards load

### Expected Behavior

- All navigation uses relative URLs
- Back buttons go to `/` or parent lab
- No `localhost:8080` in URLs
- No Cloud Run URLs in navigation
