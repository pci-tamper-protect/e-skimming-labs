# Troubleshooting Guide

Common issues and solutions for E-Skimming Labs.

## Quick Fixes

| Problem | Solution |
|---------|----------|
| 401 Unauthorized | Restart provider: `docker compose -f docker-compose.sidecar-local.yml restart provider` |
| "invalid_grant" error | Re-authenticate: `gcloud auth application-default login` |
| Lab shows home page instead | **Likely expired ADC** - see below |
| Lab shows C2 content | Redeploy: `./deploy/deploy-labs.sh stg 02 --force-rebuild` |
| Stale content | Restart proxy or provider |
| 404 Not Found | Check provider logs for route generation errors |

## Authentication Issues

### Lab Shows Home Page Instead of Lab Content

**This is the most confusing symptom of expired credentials.**

**What happens:** You click on Lab 1, the URL changes to `/lab1`, but you see the home page content instead of the lab.

**Why this happens:**
1. When ADC expires, the Traefik provider can't generate identity tokens
2. Without valid tokens, requests to lab services get 401 Unauthorized
3. Traefik's retry middleware eventually falls through to the home-index route
4. Home-index has the lowest priority (catches all unmatched routes)
5. So you see the home page at `/lab1` URL

**Solution:**
```bash
# Refresh credentials
gcloud auth application-default login

# Restart the provider to get fresh tokens
docker compose -f docker-compose.sidecar-local.yml restart provider

# Wait a few seconds for routes to regenerate
sleep 5

# Test again
curl http://localhost:9090/lab1
```

**How to verify this is the issue:**
```bash
# Check provider logs for token errors
docker compose -f docker-compose.sidecar-local.yml logs provider | grep -i "token\|auth\|error"

# Look for messages like:
# - "invalid_grant"
# - "reauth related error"
# - "Failed to get identity token"
```

### 401 Unauthorized

**Cause:** Identity tokens have expired or ADC is invalid.

**Symptoms:**
- Direct 401 errors in browser or curl
- Lab pages showing home page instead (see above)
- Provider logs showing token fetch failures

**Solution:**
```bash
# First, check if ADC is the issue
gcloud auth application-default print-access-token

# If that fails, refresh ADC
gcloud auth application-default login

# Then restart provider
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### "invalid_grant" / "reauth related error"

**Cause:** Your gcloud Application Default Credentials have expired or been revoked.

**Why ADC expires:**
- ADC tokens are valid for ~1 hour
- If you haven't used gcloud in a while, tokens expire
- Some corporate environments have shorter token lifetimes

**Solution:**
```bash
gcloud auth application-default login
docker compose -f docker-compose.sidecar-local.yml restart provider
```

**Prevention:** The provider automatically refreshes tokens every 25 minutes, but this only works if the underlying ADC is valid.

### "unsupported credentials type: authorized_user"

**Cause:** User credentials can't generate identity tokens directly.

**Solution:** Set up service account impersonation:
```bash
gcloud projects add-iam-policy-binding labs-stg \
  --member="user:YOUR_EMAIL" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --condition=None
```

### 403 Forbidden (Staging)

**Cause:** Your account doesn't have access to staging.

**Solution:** Contact admin to be added to authorized groups.

## Routing Issues

### 404 Not Found

**Cause:** Route not configured or service not discovered.

**Check:**
```bash
# Provider logs
docker compose -f docker-compose.sidecar-local.yml logs provider

# Generated routes
docker compose -f docker-compose.sidecar-local.yml exec traefik \
  cat /shared/traefik/dynamic/routes.yml
```

### Lab Shows Wrong Content (C2 at root)

**Cause:** C2 server binding to port 8080 instead of 3000.

**Solution:**
1. Check `init.sh` uses `C2_PORT=3000`
2. Redeploy: `./deploy/deploy-labs.sh stg 02 --force-rebuild`
3. Restart provider

### Navigation Goes to localhost:8080

**Cause:** Old code with hardcoded URLs.

**Solution:**
1. Check HTML/JS for hardcoded URLs
2. Update to use relative URLs
3. Redeploy the service

### Home-index Catches All Routes

**Cause:** Home-index router has higher priority than lab routes.

**Solution:** Home-index should have `priority: 1` (lowest). Check:
```bash
docker compose -f docker-compose.sidecar-local.yml exec traefik \
  cat /shared/traefik/dynamic/home-index.yml
```

## Deployment Issues

### Docker Build Uses Cached Layers

**Solution:** Use `--force-rebuild` or `--no-cache`:
```bash
./deploy/deploy-labs.sh stg 02 --force-rebuild

# Or manually
docker build --no-cache -t image:tag .
```

### Service Not Starting

**Check Cloud Run logs:**
```bash
gcloud run services logs read SERVICE_NAME \
  --project=labs-stg \
  --region=us-central1 \
  --limit=50
```

### "declared and not used" Build Error

**Cause:** Unused variables in Go code.

**Solution:** Remove the unused variable declarations from the source file.

### Port Binding Error

**Cause:** Multiple processes trying to bind to same port.

**Solution:** Ensure C2 server uses port 3000, nginx uses 8080.

## Local Environment Issues

### Port Already in Use

```bash
# Find what's using the port
lsof -i :9090

# Kill it
lsof -ti :9090 | xargs kill -9
```

### Provider Not Generating Routes

**Check:**
```bash
# Provider logs
docker compose -f docker-compose.sidecar-local.yml logs provider

# Credentials mounted
docker compose -f docker-compose.sidecar-local.yml exec provider \
  ls -la /home/cloudrunner/.config/gcloud/
```

### Shared Volume Issues

```bash
# Check volume contents
docker compose -f docker-compose.sidecar-local.yml exec traefik \
  ls -la /shared/traefik/dynamic/

# Check file permissions
docker compose -f docker-compose.sidecar-local.yml exec traefik \
  stat /shared/traefik/dynamic/routes.yml
```

## Staging Issues

### Stale Content After Deploy

**Solution:** Restart the proxy:
```bash
pkill -f "gcloud run services proxy"
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082
```

### Service Not Found

**Check if deployed:**
```bash
gcloud run services list \
  --project=labs-stg \
  --region=us-central1
```

## Getting Help

1. Check logs first
2. Verify credentials are fresh
3. Restart provider/proxy
4. Check generated routes.yml
5. Verify service is deployed with latest code

## IAM Issues

### Check IAM Policies

```bash
# Check Traefik IAM policy
gcloud run services get-iam-policy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="json"

# Check if service has allUsers (public) access
gcloud run services get-iam-policy SERVICE_NAME \
  --region=us-central1 \
  --project=PROJECT_ID \
  --format="json" | jq '.bindings[] | select(.members[] | contains("allUsers"))'
```

### Grant Group Access

```bash
# Grant access to a group
gcloud run services add-iam-policy-binding SERVICE_NAME \
  --region=us-central1 \
  --project=PROJECT_ID \
  --member="group:GROUP_EMAIL" \
  --role="roles/run.invoker"
```

### Grant Artifact Registry Permissions

```bash
# Grant repository-level writer role
gcloud artifacts repositories add-iam-policy-binding e-skimming-labs \
  --location=us-central1 \
  --project=labs-stg \
  --member="user:YOUR_EMAIL" \
  --role="roles/artifactregistry.writer"

# Configure Docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev
```

## Useful Commands

```bash
# View all container logs
docker compose -f docker-compose.sidecar-local.yml logs -f

# Check router status
curl http://localhost:9091/api/http/routers | jq

# Check service status
gcloud run services describe SERVICE_NAME \
  --project=PROJECT_ID \
  --region=us-central1 \
  --format="yaml(status)"

# View Cloud Run logs
gcloud run services logs read SERVICE_NAME \
  --project=PROJECT_ID \
  --region=us-central1 \
  --limit=50

# Debug Traefik startup (sidecar logs)
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=traefik \
  --limit=100

# Debug provider sidecar
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=provider \
  --limit=50
```
