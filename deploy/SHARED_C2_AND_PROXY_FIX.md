# Shared C2 Service and Proxy Authentication Fix

## Changes Made

### 1. Shared C2 Service
- **Added**: Single shared C2 service deployed at `/c2` (accessible at `localhost:8082/c2` or `https://labs.stg.pcioasis.com/c2`)
- **Location**: `deploy/deploy-all-stg.sh` - Step 5
- **Service Name**: `shared-c2-stg`
- **Dockerfile**: Uses `labs/01-basic-magecart/malicious-code/c2-server/Dockerfile`
- **Traefik Route**: `PathPrefix(\`/c2\`)` with `strip-c2-prefix` middleware
- **Public**: `--allow-unauthenticated` (public for now)

### 2. Updated Lab Services
- **C2_URL**: Changed from lab-specific URLs to shared URL: `https://${DOMAIN_PREFIX}/c2`
- **All labs** (Lab 1, 2, 3) now use the shared C2 service

### 3. Traefik Middleware
- **Added**: `strip-c2-prefix` middleware in `deploy/traefik/dynamic/routes.yml`
- Strips `/c2` prefix before forwarding to C2 service

### 4. Services Made Public (Temporary)
- **Changed**: All services from `--no-allow-unauthenticated` to `--allow-unauthenticated`
- **Reason**: Proxy authentication not working yet - keeping public until proxy is fixed
- **Services affected**:
  - `traefik-stg`
  - `home-index-stg`
  - `lab-01-basic-magecart-stg`
  - `lab-02-dom-skimming-stg`
  - `lab-03-extension-hijacking-stg`

## Proxy Authentication Issue

### Current Problem
When accessing via `gcloud run services proxy` on `localhost:8082`:
- ✅ Home page works (`localhost:8082/`)
- ❌ Lab 1 returns 401 (`localhost:8082/lab1`)

### Root Cause
The 401 error suggests that when Traefik is accessed via the proxy:
1. The proxy authenticates to Traefik correctly (home page works)
2. But Traefik fails to generate/pass IAM tokens to backend services (labs)

### Why It Works When Public
When services are public (`--allow-unauthenticated`):
- Traefik doesn't need to generate IAM tokens
- Requests go through without authentication
- This is why `labs.stg.pcioasis.com` works

### Why Proxy Fails
When services are private (`--no-allow-unauthenticated`):
- Traefik must generate IAM tokens for backend services
- The token generation happens in `entrypoint.sh` or `generate-routes-from-labels.sh`
- The auth middleware adds `Authorization: Bearer <token>` header
- If token generation fails or token is invalid, backend returns 401

## Next Steps to Fix Proxy

1. **Verify Token Generation**: Check if Traefik is generating tokens correctly
   - Check Traefik logs for token generation messages
   - Verify `traefik-stg` service account has `roles/iam.serviceAccountTokenCreator`

2. **Verify Token Passing**: Check if tokens are being passed in requests
   - Use `debug-lab1-service-auth.sh` to test token generation
   - Check Traefik logs for `Authorization` header in requests

3. **Check forwardAuth**: Verify forwardAuth middleware works through proxy
   - `home-index-service` should bypass auth for proxy access (already implemented)
   - Check if `X-Forwarded-For` and `X-Forwarded-Host` headers are being forwarded

4. **Test with Private Services**: Once proxy works, make services private again
   - Change `--allow-unauthenticated` back to `--no-allow-unauthenticated`
   - Test via proxy to ensure authentication works

## Testing

### Test Shared C2
```bash
# Via proxy
curl http://localhost:8082/c2

# Via public domain
curl https://labs.stg.pcioasis.com/c2
```

### Test Proxy Authentication
```bash
# Start proxy
./deploy/traefik/proxy-traefik-stg.sh

# Test home page (should work)
curl http://localhost:8082/

# Test lab 1 (currently returns 401 when services are private)
curl http://localhost:8082/lab1

# Debug authentication
./deploy/traefik/debug/debug-lab1-service-auth.sh stg
```

## Files Modified

1. `deploy/deploy-all-stg.sh` - Added shared C2 service, updated C2_URLs, made services public
2. `deploy/traefik/dynamic/routes.yml` - Added `strip-c2-prefix` middleware



