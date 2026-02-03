# Traefik Route Refresh Strategy

This document explains how Traefik routes stay up-to-date with Cloud Run service deployments.

## Problem

Unlike Docker (where Traefik watches the Docker socket), Cloud Run services are deployed independently. We need to:
1. **Initial discovery**: Find all services when Traefik starts
2. **Ongoing updates**: Keep routes updated when new services are deployed

## Solution: Multiple Refresh Mechanisms

### 1. Startup Generation (Current)
- Runs when Traefik container starts
- Queries all Cloud Run services
- Generates initial routes.yml
- **Limitation**: Doesn't catch services deployed after Traefik starts

### 2. Periodic Refresh (Implemented)
- Background process with adaptive refresh rate:
  - **First minute**: Refreshes every 5 seconds (fast discovery)
  - **After first minute**: Refreshes every 5 minutes (normal operation)
- Regenerates routes.yml automatically
- Traefik file provider watches and reloads config
- **Pros**: Simple, works automatically, fast initial discovery
- **Cons**: Up to 5 minute delay for services deployed after first minute

### 3. Eventarc (Optional - Real-time)
- Listen for Cloud Run service creation/update events
- Trigger route regeneration immediately
- **Pros**: Real-time updates, no polling
- **Cons**: More complex setup, requires Eventarc configuration

### 4. Manual Refresh Endpoint (Optional)
- HTTP endpoint to trigger refresh on-demand
- Useful for testing or immediate updates
- **Pros**: Immediate, on-demand
- **Cons**: Requires manual trigger or external system

## Current Implementation

### Periodic Refresh

The `entrypoint.sh` script starts a background process that:
1. **First minute**: Runs every 5 seconds (fast discovery)
2. **After first minute**: Runs every 5 minutes (normal operation)
3. Calls `refresh-routes.sh`
4. Regenerates routes.yml
5. Traefik automatically reloads (file provider watch enabled)

```bash
# Background refresh process with adaptive timing
START_TIME=$(date +%s)
FAST_REFRESH_END=$((START_TIME + 60))  # First 60 seconds

while true; do
  CURRENT_TIME=$(date +%s)
  
  if [ $CURRENT_TIME -lt $FAST_REFRESH_END ]; then
    sleep 5   # Fast refresh: every 5 seconds
  else
    sleep 300 # Normal refresh: every 5 minutes
  fi
  
  /app/refresh-routes.sh /etc/traefik/dynamic/routes.yml
done
```

### How It Works

1. **Traefik starts** → Generates routes from all existing services
2. **Background process starts** → Fast refresh (every 5s) for first minute
3. **New service deployed** → Discovered within 5 seconds (if in first minute) or 5 minutes (after)
4. **routes.yml updated** → Traefik file provider detects change
5. **Traefik reloads** → New routes available immediately
6. **After first minute** → Switches to 5-minute refresh interval

## File Provider Watch

Traefik is configured with `watch: true`:

```yaml
providers:
  file:
    directory: /etc/traefik/dynamic
    watch: true  # Automatically reloads on file changes
```

This means:
- Any change to routes.yml triggers automatic reload
- No Traefik restart needed
- Zero downtime updates

## Eventarc Option (Advanced)

For real-time updates, you can set up Eventarc:

### 1. Create Eventarc Trigger

```bash
gcloud eventarc triggers create traefik-route-refresh \
  --location=us-central1 \
  --destination-run-service=traefik-stg \
  --destination-run-path=/refresh-routes \
  --event-filters="type=google.cloud.run.service.created" \
  --event-filters="type=google.cloud.run.service.updated" \
  --service-account=traefik-stg@labs-stg.iam.gserviceaccount.com
```

### 2. Add Refresh Endpoint to Traefik

Create a simple HTTP endpoint that calls `refresh-routes.sh`:

```bash
# In entrypoint.sh or separate service
# Listen on port 8082 for refresh requests
while true; do
  echo -e "HTTP/1.1 200 OK\r\n\r\n" | nc -l -p 8082
  /app/refresh-routes.sh
done
```

### 3. Benefits

- **Real-time**: Routes update within seconds of service deployment
- **Efficient**: No polling, only triggers on actual changes
- **Reliable**: Event-driven, no missed updates

## Monitoring

Check refresh logs:
```bash
# In Traefik container
tail -f /tmp/traefik-refresh.log
```

Monitor Traefik reloads:
- Traefik logs show "Configuration loaded from file"
- Dashboard shows updated router count
- Access logs show new routes working

## Tuning

Adjust refresh intervals in `entrypoint.sh`:

**Fast refresh period:**
```bash
FAST_REFRESH_END=$((START_TIME + 60))  # Change 60 to adjust duration (seconds)
sleep 5  # Change 5 to adjust fast refresh interval (seconds)
```

**Normal refresh interval:**
```bash
sleep 300  # Change to 60 for 1-minute, 600 for 10-minute
```

**Trade-offs:**
- **Faster initial refresh** (more frequent): Catches services deployed right after Traefik starts
- **Longer fast period**: More API calls initially, but better for rapid deployments
- **Shorter fast period**: Fewer API calls, but may miss services deployed 30-60s after startup
- **Current (5s for 60s, then 5min)**: Good balance - fast initial discovery, efficient long-term

## Service Readiness

**Q: What if a service isn't ready when routes are generated?**

**A:** The script handles this gracefully:
1. Service may not exist yet → Script skips it (no error)
2. Service exists but no labels → Script skips it
3. Service has labels → Routes generated
4. Next refresh (5 min) → New service discovered

**Best practice:** Deploy services with Traefik labels, then Traefik will discover them within 5 minutes.

## Comparison to Docker

| Aspect | Docker | Cloud Run (Current) | Cloud Run (Eventarc) |
|--------|--------|---------------------|---------------------|
| Discovery | Real-time (socket watch) | 5-minute polling | Real-time (events) |
| Setup | Simple (socket mount) | Simple (background script) | Complex (Eventarc) |
| Reliability | High | High | Very High |
| Latency | Instant | 0-5 minutes | < 1 second |

## Recommendation

**Start with periodic refresh** (current implementation):
- Simple and reliable
- 5-minute delay is acceptable for most deployments
- No additional infrastructure needed

**Upgrade to Eventarc if:**
- You need real-time route updates
- You deploy services frequently
- 5-minute delay is unacceptable
