# Cold Start Configuration

This document explains how Traefik handles cold starts for Cloud Run services that scale to zero.

## Architecture

- **Traefik**: Always running (min-instances=1) - handles routing and retries
- **Backend Services**: Scale to zero (min-instances=0) - saves costs, cold starts handled by retries

## Configuration

### 1. Traefik Min Instances

Traefik is configured to always have at least 1 instance running:

```bash
--min-instances=1
```

This ensures Traefik is always available to:
- Route incoming requests
- Retry failed requests during cold starts
- Provide consistent latency for routing decisions

### 2. Retry Middleware

All routers automatically include `retry-cold-start@file` middleware defined in `routes.yml`:

```yaml
retry-cold-start:
  retry:
    attempts: 3
    initialInterval: 100ms
    maxInterval: 1s
    multiplier: 2
    retryOn: "5xx,gateway-error,connect-failure,refused-stream"
```

**How it works:**
- **attempts: 3** - Retries up to 3 times
- **initialInterval: 100ms** - First retry after 100ms
- **maxInterval: 1s** - Maximum wait between retries
- **multiplier: 2** - Exponential backoff (100ms → 200ms → 400ms)
- **retryOn** - Only retries on:
  - `5xx` - Server errors (service starting up)
  - `gateway-error` - Gateway errors
  - `connect-failure` - Connection failures (service not ready)
  - `refused-stream` - Stream refused (service starting)

### 3. Automatic Application

The retry middleware is automatically added to all routers:

1. **traefik-cloudrun-provider**:
   - Automatically adds `retry-cold-start@file` to all routers
   - Checks if already present to avoid duplicates

2. **Static routes** (`routes.yml`):
   - Manually include `retry-cold-start@file` in middleware list

## Cold Start Flow

1. **Request arrives** at Traefik (always running)
2. **Traefik routes** to backend service (may be cold)
3. **First attempt fails** (service starting) → 503/502/connection error
4. **Retry middleware** waits 100ms
5. **Second attempt** → May succeed if service started
6. **If still failing**, retry with exponential backoff
7. **After 3 attempts**, return error to client

## Benefits

- **Cost savings**: Backend services scale to zero when idle
- **Reliability**: Retries handle transient cold start failures
- **User experience**: Most cold starts complete within 1-2 retries
- **No code changes**: Retry logic handled by Traefik, not services

## Monitoring

Monitor cold start behavior:
- Traefik access logs show retry attempts
- Cloud Run metrics show cold start frequency
- Response times indicate cold start impact

## Tuning

Adjust retry parameters in `routes.yml` if needed:
- Increase `attempts` for slower-starting services
- Increase `initialInterval` if services need more time
- Adjust `maxInterval` based on typical cold start duration
