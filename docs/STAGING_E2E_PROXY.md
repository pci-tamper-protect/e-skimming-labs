# Staging E2E Tests with gcloud Proxy

## Overview

Staging E2E tests now use `gcloud run services proxy` to access the staging environment through Traefik. This allows tests to:
- Avoid browser authentication issues
- Use relative URLs for navigation
- Test the same routing as production (through Traefik)

## How It Works

### GitHub Actions Workflow

The `.github/workflows/deploy_labs.yml` workflow automatically:

1. **Authenticates to Google Cloud** (for staging only)
   - Uses `LABS_GCP_SA_KEY` (service account key)
   - Service account: `labs-deploy-sa@labs-stg.iam.gserviceaccount.com`

2. **Starts the proxy** (for staging only)
   ```bash
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8082
   ```
   - Port 8082 is used by default (configurable via `STG_PROXY_PORT` in `.env.stg`)
   - Port 8082 avoids conflicts with local dev (8080) and Traefik dashboard (8081)
   - Runs in background
   - Waits up to 30 seconds for proxy to be ready
   - Exports `PROXY_URL` and `USE_PROXY` environment variables

3. **Runs tests** with proxy URL
   - Tests use `http://127.0.0.1:8082` instead of `https://labs.stg.pcioasis.com`
   - All navigation uses relative URLs (works through proxy)

4. **Cleans up** (always, even on failure)
   - Stops the proxy process
   - Kills any remaining proxy processes

### Test Configuration

The `test/config/test-env.js` automatically detects proxy usage:

```javascript
stg: {
  // Uses PROXY_URL if available (CI/CD), otherwise direct domain
  homeIndex: process.env.PROXY_URL && process.env.USE_PROXY === 'true' 
    ? process.env.PROXY_URL 
    : 'https://labs.stg.pcioasis.com',
  // Lab URLs also use proxy paths when available
  lab1: {
    vulnerable: process.env.PROXY_URL && process.env.USE_PROXY === 'true'
      ? `${process.env.PROXY_URL}/lab1`
      : 'https://lab-01-basic-magecart-stg-...',
    // ...
  }
}
```

## Service Account Requirements

The GitHub Actions runner needs a service account with permissions to:
- Run `gcloud run services proxy` command
- Access Traefik service in `labs-stg` project

**Required IAM roles:**
- `roles/run.viewer` (to view service details)
- `roles/run.invoker` (to invoke the proxy)

The service account `labs-deploy-sa@labs-stg.iam.gserviceaccount.com` should already have these permissions.

## Environment Variables

When running tests in CI/CD with proxy:

- `PROXY_URL`: `http://127.0.0.1:8082` (set by workflow, configurable via `STG_PROXY_PORT` in `.env.stg`)
- `USE_PROXY`: `true` (set by workflow)
- `TEST_ENV`: `stg` (set by workflow)

## Local Testing

For local testing, you can manually start the proxy:

```bash
# Start proxy (using helper script - recommended)
./deploy/traefik/proxy-traefik-stg.sh &

# Or manually (default port is 8082):
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082 &

# Set environment variables
export PROXY_URL="http://127.0.0.1:8082"
export USE_PROXY="true"
export TEST_ENV="stg"

# Run tests
cd test
npm test
```

## Troubleshooting

### Proxy fails to start

**Symptoms:**
- Tests fail with connection errors
- Proxy log shows errors

**Solutions:**
1. Check service account permissions:
   ```bash
   gcloud projects get-iam-policy labs-stg \
     --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:labs-deploy-sa@labs-stg.iam.gserviceaccount.com"
   ```

2. Verify Traefik service exists:
   ```bash
   gcloud run services describe traefik-stg \
     --region=us-central1 \
     --project=labs-stg
   ```

3. Check proxy logs in workflow output

### Tests still use absolute URLs

**Symptoms:**
- Tests navigate to `https://labs.stg.pcioasis.com` instead of proxy

**Solutions:**
1. Verify `PROXY_URL` and `USE_PROXY` are set:
   ```bash
   echo "PROXY_URL: $PROXY_URL"
   echo "USE_PROXY: $USE_PROXY"
   ```

2. Check test configuration logs:
   - Look for "🔗 Using gcloud proxy: http://127.0.0.1:8082"
   - Verify `currentEnv.homeIndex` shows proxy URL

3. Ensure home-index-service is deployed with latest code (proxy detection)

### Proxy process doesn't stop

**Symptoms:**
- Workflow hangs or times out
- Multiple proxy processes running

**Solutions:**
1. The cleanup step should handle this automatically
2. If issues persist, check the cleanup step logs
3. Manual cleanup (if needed):
   ```bash
   pkill -f "gcloud run services proxy"
   ```

## Benefits

✅ **No browser authentication needed** - Proxy handles IAM automatically  
✅ **Consistent routing** - Tests go through Traefik (same as production)  
✅ **Relative URLs work** - Navigation stays within proxy  
✅ **Faster tests** - No authentication overhead  
✅ **Better debugging** - Can check proxy logs in workflow

## Related Documentation

- **[docs/STAGING.md](STAGING.md)** - Complete staging environment guide
- **[test/AUTH_SETUP.md](../test/AUTH_SETUP.md)** - E2E test authentication setup
- **[test/ENVIRONMENT_TESTING.md](../test/ENVIRONMENT_TESTING.md)** - General environment testing guide

---

**Last Updated:** 2025-12-25  
**Version:** 1.0
