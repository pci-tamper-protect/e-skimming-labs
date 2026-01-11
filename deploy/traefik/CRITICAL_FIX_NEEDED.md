# CRITICAL FIX NEEDED: gcloud Not Available in Container

## Problem

The `generate-routes-from-labels.sh` script uses `gcloud` commands extensively, but:
- **`gcloud` is NOT installed in `Dockerfile.cloudrun`** (only `curl`, `bash`, `jq`)
- **`gcloud` is NOT installed in `Dockerfile.test`** (only `curl`, `bash`, `jq`)
- **Cloud Run containers don't have `gcloud` by default**

This means **the script has been failing silently in staging for days**.

## Evidence

1. Script uses `gcloud run services list` (lines 126-150)
2. Script uses `gcloud run services describe` (lines 195-211, 208-211)
3. Dockerfile only installs: `curl ca-certificates bash jq` (line 9)
4. No `gcloud` installation in either Dockerfile

## Impact

- **No services are being discovered** (gcloud commands fail)
- **No routes are being generated** (except Traefik API routes)
- **No middleware is being created** (no services = no middleware)
- **Script fails silently** (errors are logged but script continues)

## Solution

Replace all `gcloud` commands with **Cloud Run Admin API REST calls** using `curl`:

### Current (BROKEN):
```bash
gcloud run services list --region=us-central1 --project=labs-stg --format="value(name)"
gcloud run services describe service-name --region=us-central1 --project=labs-stg --format="json"
```

### Fixed (using REST API):
```bash
# Get access token from metadata server
ACCESS_TOKEN=$(curl -s -f -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token?scopes=https://www.googleapis.com/auth/cloud-platform" | \
  jq -r '.access_token')

# List services
curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://run.googleapis.com/v1/projects/labs-stg/locations/us-central1/services" | \
  jq -r '.items[]?.metadata.name'

# Get service details
curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://run.googleapis.com/v1/projects/labs-stg/locations/us-central1/services/service-name" | \
  jq '.'
```

## Files to Update

1. **`deploy/traefik/generate-routes-from-labels.sh`**:
   - Replace `gcloud run services list` with REST API call (lines 126-150)
   - Replace `gcloud run services describe` with REST API call (lines 195-211, 208-211)
   - Add `get_access_token()` function (already added)
   - Update all service queries to use REST API

2. **Test the fix**:
   - Deploy to staging
   - Check logs for service discovery
   - Verify middleware creation

## Why This Happened

- Assumed `gcloud` would be available (it's not by default)
- Didn't test the container setup before building scripts
- Script fails silently (continues even when gcloud fails)

## Lesson Learned

**Always verify prerequisites before building features.**
- Check what's available in the container
- Test the container setup first
- Use REST APIs instead of CLI tools when possible (lighter weight)




