# Testing Traefik Sidecar Deployment on Cloud Run

## Local Sidecar Simulation (Fast Debugging)

**For fast local debugging without waiting for Cloud Logging (logs can take up to 5 minutes)**

The local sidecar simulation replicates the Cloud Run sidecar architecture locally using Docker Compose, allowing you to:
- See logs instantly (no 5-minute Cloud Logging delay)
- Debug startup issues quickly
- Test route generation before deploying
- Iterate on configuration changes rapidly

### Quick Start

```bash
# From repo root
cd e-skimming-labs

# Start local sidecar simulation
docker-compose -f docker-compose.sidecar-local.yml up -d

# View logs in real-time
docker-compose -f docker-compose.sidecar-local.yml logs -f

# Run tests
./deploy/traefik/test-sidecar-local.sh

# Stop when done
docker-compose -f docker-compose.sidecar-local.yml down
```

### Architecture

The local simulation includes:
1. **Main Traefik container** - Serves web traffic on `localhost:9090` (container port 8080)
2. **Provider sidecar** - Generates `routes.yml` into shared volume (polls Cloud Run API every 30s)
3. **Shared volumes** - `shared-routes` for routes.yml, `shared-stats` for future use
4. **Dashboard service** - Separate service on `localhost:9091`

**Port Configuration:**
- Gateway: `localhost:9090` (mapped from container port 8080)
- Dashboard: `localhost:9091` (mapped from container port 8080)
- Token refresh: Every 25 minutes (configurable via `TOKEN_CACHE_DURATION`)

### Prerequisites for Local Simulation

1. **Google Cloud credentials**:
   ```bash
   # Ensure you have ADC credentials
   gcloud auth application-default login
   ```

2. **Service Account Impersonation** (required for identity tokens):
   
   User credentials from `gcloud auth application-default login` cannot directly generate 
   identity tokens for Cloud Run services. The provider uses service account impersonation 
   to work around this limitation.

   ```bash
   # First, ensure a service account exists with Cloud Run Invoker role
   # (This may already exist - check with: gcloud iam service-accounts list --project=labs-stg)
   gcloud iam service-accounts create traefik-stg \
     --project=labs-stg \
     --display-name="Traefik Provider"
   
   # Grant the service account permission to invoke Cloud Run services
   gcloud projects add-iam-policy-binding labs-stg \
     --member="serviceAccount:traefik-stg@labs-stg.iam.gserviceaccount.com" \
     --role="roles/run.invoker"
   
   # Grant YOUR user account permission to impersonate this service account
   # Replace YOUR_EMAIL with your Google account email
   gcloud iam service-accounts add-iam-policy-binding \
     traefik-stg@labs-stg.iam.gserviceaccount.com \
     --project=labs-stg \
     --member="user:YOUR_EMAIL" \
     --role="roles/iam.serviceAccountTokenCreator"
   ```

   The `docker-compose.sidecar-local.yml` is pre-configured to use `traefik-stg@labs-stg.iam.gserviceaccount.com`.
   To use a different service account, set `IMPERSONATE_SERVICE_ACCOUNT` in your environment or `.env` file.

3. **Environment variables** (optional, defaults provided):
   ```bash
   export ENVIRONMENT=stg
   export LABS_PROJECT_ID=labs-stg
   export HOME_PROJECT_ID=labs-home-stg
   export REGION=us-central1
   export POLL_INTERVAL=30s
   # Override default service account for impersonation (optional)
   export IMPERSONATE_SERVICE_ACCOUNT=your-sa@your-project.iam.gserviceaccount.com
   ```

### Usage

#### Start Services

```bash
docker-compose -f docker-compose.sidecar-local.yml up -d
```

#### View Logs

```bash
# All services
docker-compose -f docker-compose.sidecar-local.yml logs -f

# Just Traefik
docker-compose -f docker-compose.sidecar-local.yml logs -f traefik

# Just Provider
docker-compose -f docker-compose.sidecar-local.yml logs -f provider

# Just Dashboard
docker-compose -f docker-compose.sidecar-local.yml logs -f traefik-dashboard
```

#### Test Services

```bash
# Run comprehensive automated tests
./deploy/traefik/test-sidecar-local.sh

# Run with verbose output (shows more details)
./deploy/traefik/test-sidecar-local.sh --verbose

# Manual health check
curl http://localhost:9090/ping

# Test home page
curl http://localhost:9090/

# Test lab routing
curl http://localhost:9090/lab1
curl http://localhost:9090/lab2
curl http://localhost:9090/lab3

# Check API
curl http://localhost:9090/api/rawdata

# Check Dashboard
curl http://localhost:9091/dashboard/

# Check Dashboard API proxy
curl http://localhost:9091/api/version
```

#### Test Coverage

The test script (`test-sidecar-local.sh`) validates:

1. **Service Status** - All containers are running
2. **Traefik Readiness** - Main Traefik service responds to health checks
3. **Provider Route Generation** - Provider generates routes.yml into shared volume
4. **Shared Volume** - Both Traefik and provider can access routes.yml
5. **Traefik Endpoints** - `/ping`, `/api/rawdata`, `/metrics` are accessible
6. **Dashboard Service** - Dashboard UI and API proxy are working
7. **Provider Logs** - Route generation activity is logged
8. **Traefik Logs** - Configuration loaded and file provider active
9. **Route Discovery** - Application routes are discovered from Cloud Run
10. **Configuration Validation** - Config files exist and have required settings

**Note**: Provider auth errors (like "invalid_rapt") are expected if ADC credentials need refreshing. Run `gcloud auth application-default login` to refresh credentials.

#### Debugging

```bash
# Check if routes.yml was generated
docker-compose -f docker-compose.sidecar-local.yml exec provider \
  cat /shared/traefik/dynamic/routes.yml

# Check Traefik config
docker-compose -f docker-compose.sidecar-local.yml exec traefik \
  cat /etc/traefik/traefik.yml

# Check shared volume contents
docker-compose -f docker-compose.sidecar-local.yml exec traefik \
  ls -la /shared/traefik/dynamic/

# Restart a service
docker-compose -f docker-compose.sidecar-local.yml restart traefik
docker-compose -f docker-compose.sidecar-local.yml restart provider
```

#### Stop Services

```bash
docker-compose -f docker-compose.sidecar-local.yml down

# Remove volumes (clean slate)
docker-compose -f docker-compose.sidecar-local.yml down -v
```

### Differences from Cloud Run

| Feature | Cloud Run | Local Simulation |
|---------|-----------|------------------|
| Logs | 5-minute delay | Instant |
| Networking | Cloud Run internal | Docker bridge network |
| Credentials | Service account | ADC or service account key |
| Volumes | In-memory emptyDir | Docker named volumes |
| Port binding | 0.0.0.0:8080 required | 0.0.0.0:8080 (same) |
| Health checks | Startup/liveness probes | Docker healthcheck |

### Troubleshooting Local Simulation

**"Failed to fetch identity token" / "unsupported credentials type: authorized_user"**:

This error occurs because user credentials from `gcloud auth application-default login` cannot 
directly generate identity tokens. The provider needs to impersonate a service account.

```bash
# 1. Ensure IMPERSONATE_SERVICE_ACCOUNT is set in docker-compose.sidecar-local.yml
#    (it defaults to traefik-stg@labs-stg.iam.gserviceaccount.com)

# 2. Grant yourself permission to impersonate the service account
#    Replace YOUR_EMAIL with your Google account email
gcloud iam service-accounts add-iam-policy-binding \
  traefik-stg@labs-stg.iam.gserviceaccount.com \
  --project=labs-stg \
  --member="user:YOUR_EMAIL" \
  --role="roles/iam.serviceAccountTokenCreator"

# 3. Rebuild and restart the provider
docker-compose -f docker-compose.sidecar-local.yml build provider
docker-compose -f docker-compose.sidecar-local.yml up -d provider
docker-compose -f docker-compose.sidecar-local.yml logs -f provider
```

**Provider can't access Cloud Run API**:
```bash
# Refresh ADC credentials (fixes "invalid_grant" / "invalid_rapt" errors)
gcloud auth application-default login

# Check credentials are mounted
docker-compose -f docker-compose.sidecar-local.yml exec provider \
  ls -la /home/cloudrunner/.config/gcloud/application_default_credentials.json

# Test credentials
docker-compose -f docker-compose.sidecar-local.yml exec provider \
  env | grep GOOGLE_APPLICATION_CREDENTIALS
```

**404 on root path (`/`)**:

If `localhost:9090/` returns 404 but the remote Cloud Run service works directly:

1. **Check router status**:
   ```bash
   curl -s http://localhost:9090/api/http/routers | \
     python3 -c "import sys, json; r=json.load(sys.stdin); \
     h=[x for x in r if 'home-index' in x['name']]; \
     [print(f\"{x['name']}: priority={x.get('priority',0)}, service={x.get('service','N/A')}, status={x.get('status','N/A')}\") for x in h]"
   ```
   Should show `home-index@file` with `priority=100`, `service=home-index`, `status=enabled`.

2. **Verify passHostHeader is false** (critical for Cloud Run):
   ```bash
   docker exec e-skimming-labs-traefik-sidecar-local \
     cat /shared/traefik/dynamic/home-index.yml | grep passHostHeader
   # Must show: passHostHeader: false
   
   # If it shows 'true', fix it:
   docker exec e-skimming-labs-traefik-sidecar-local \
     sed -i 's/passHostHeader: true/passHostHeader: false/' \
     /shared/traefik/dynamic/home-index.yml
   docker-compose -f docker-compose.sidecar-local.yml restart traefik
   sleep 5
   ```

3. **Clear browser cache** or test with curl:
   ```bash
   curl -v http://localhost:9090/
   # Should return 200 with HTML content
   ```

4. **Check for router conflicts**:
   ```bash
   # The provider may generate a conflicting router in routes.yml
   docker exec e-skimming-labs-traefik-sidecar-local \
     cat /shared/traefik/dynamic/routes.yml | grep -A 5 "home-index:"
   # If it shows service: "", that's a conflict (but home-index.yml should win with priority 100)
   ```

5. **Force regenerate route**:
   ```bash
   docker exec e-skimming-labs-traefik-sidecar-local \
     rm /shared/traefik/dynamic/home-index.yml
   docker-compose -f docker-compose.sidecar-local.yml restart traefik
   sleep 5
   curl http://localhost:9090/
   ```

### Lab links redirect to Cloud Run URLs instead of localhost:9090/lab1

**This issue has been fixed.** Services now always use relative URLs (`/lab1`, `/lab2`, etc.) and Traefik handles all routing.

If you still see absolute URLs being generated:
1. The deployed service may be outdated - redeploy with `./deploy/deploy-home.sh stg --force-rebuild`
2. Clear browser cache or use incognito mode
3. Restart the provider: `docker compose -f docker-compose.sidecar-local.yml restart provider`

**Architecture Principle**: Services must NOT contain routing logic. All routing belongs to Traefik. See [ROUTING_ARCHITECTURE.md](../../ROUTING_ARCHITECTURE.md).
This is **expected behavior** when the provider can't discover Cloud Run services. The provider only generates:
- API routes (`/api/*`)
- Dashboard routes (`/dashboard/*`)

To get application routes (like `/`, `/lab1`, etc.):
1. Fix provider authentication (see above)
2. Ensure Cloud Run services have `traefik.enable=true` labels
3. Wait for provider to regenerate routes (every 30s by default)

You can verify available routes:
```bash
curl http://localhost:9090/api/http/routers | jq -r '.[] | "\(.name): \(.rule)"'
```

**Routes not being generated**:
```bash
# Check provider logs for errors
docker-compose -f docker-compose.sidecar-local.yml logs provider

# Verify shared volume is mounted
docker-compose -f docker-compose.sidecar-local.yml exec provider \
  ls -la /shared/traefik/dynamic/
```

**Traefik can't read routes.yml**:
```bash
# Check if file exists
docker-compose -f docker-compose.sidecar-local.yml exec traefik \
  ls -la /shared/traefik/dynamic/routes.yml

# Check file permissions
docker-compose -f docker-compose.sidecar-local.yml exec traefik \
  stat /shared/traefik/dynamic/routes.yml
```

**Port conflicts**:
```bash
# Check if port 8080 is in use
lsof -i :8080

# Use different ports (edit docker-compose.sidecar-local.yml)
# Change '8080:8080' to '8082:8080' for example
```

---

## Cloud Run Deployment

## Prerequisites

1. **Authenticated to GCP**:
   ```bash
   gcloud auth login
   gcloud config set project labs-stg  # or labs-prd
   ```

2. **Docker authenticated to Artifact Registry**:
   ```bash
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

3. **Required permissions**:
   - `roles/run.admin` - Deploy Cloud Run services
   - `roles/artifactregistry.writer` - Push Docker images
   - `roles/iam.serviceAccountUser` - Use service accounts

## Deployment

### Step 1: Deploy All Services

```bash
cd deploy/traefik
./deploy-sidecar.sh stg
```

This will:
- Build 3 Docker images (main Traefik, provider, dashboard)
- Push images to Artifact Registry
- Deploy main Traefik service with provider sidecar
- Deploy dashboard service separately

### Step 2: Verify Deployment

```bash
# Check main Traefik service
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="yaml(status)"

# Check dashboard service
gcloud run services describe traefik-dashboard-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="yaml(status)"
```

## Testing

### 1. Get Service URLs

```bash
# Main Traefik service URL
MAIN_URL=$(gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="value(status.url)")

# Dashboard service URL
DASHBOARD_URL=$(gcloud run services describe traefik-dashboard-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="value(status.url)")

echo "Main Traefik: ${MAIN_URL}"
echo "Dashboard: ${DASHBOARD_URL}"
```

### 2. Test Main Traefik Service

```bash
# Health check (should return 200 OK)
curl -v "${MAIN_URL}/ping"

# Test routing to home page (requires authentication token)
# Get identity token for service account
TOKEN=$(gcloud auth print-identity-token)

# Test home route (if home-index service exists)
curl -v -H "Authorization: Bearer ${TOKEN}" "${MAIN_URL}/"

# Test API endpoint (should return 404 or 401 if not authenticated)
curl -v "${MAIN_URL}/api/version"
```

### 3. Test Provider Sidecar

```bash
# Check provider logs (should show route generation)
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=provider \
  --limit=50

# Look for:
# - "🚀 Starting traefik-cloudrun-provider"
# - "✅ Routes file generated at /shared/traefik/dynamic/routes.yml"
# - Route generation summary
```

### 4. Test Main Traefik Container

```bash
# Check main Traefik logs
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=traefik \
  --limit=50

# Look for:
# - "Configuration loaded from file: /etc/traefik/traefik.yml"
# - "file provider: watching directory /shared/traefik/dynamic"
# - No plugin compilation errors
```

### 5. Test Dashboard Service

```bash
# Test dashboard accessibility
curl -v "${DASHBOARD_URL}/dashboard/"

# Test dashboard API proxy (should proxy to main Traefik)
curl -v "${DASHBOARD_URL}/api/version"

# Check dashboard logs
gcloud run services logs read traefik-dashboard-stg \
  --region=us-central1 \
  --project=labs-stg \
  --limit=50
```

### 6. Verify Routes Generation

```bash
# Check if routes.yml is being generated
# (This requires exec access, which Cloud Run doesn't provide directly)
# Instead, check provider logs for generation confirmation

# Look for route generation in provider logs:
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=provider \
  --format="value(textPayload)" | grep -i "route"

# Should show:
# - "🔍 Generating Traefik routes from Cloud Run service labels..."
# - "✅ Routes file generated at /shared/traefik/dynamic/routes.yml"
# - Summary of routers and services found
```

### 7. Test Route Updates

```bash
# The provider runs in daemon mode and polls every 30s
# To test route updates:

# 1. Add a new label to a Cloud Run service
gcloud run services update lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg \
  --update-labels="traefik.enable=true,traefik.http.routers.test.rule=PathPrefix(\`/test\`)"

# 2. Wait 30-60 seconds for provider to poll

# 3. Check provider logs for update
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=provider \
  --limit=20 | grep -i "regenerating\|generation"
```

### 8. Test Shared Volume

The shared volume is in-memory and not directly accessible, but you can verify it's working by:

```bash
# Check that main Traefik is reading routes from shared volume
# Look for file provider watching the shared directory:
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=traefik \
  --format="value(textPayload)" | grep -i "file provider\|watching\|routes"

# Should show:
# - "file provider: watching directory /shared/traefik/dynamic"
# - Route updates when provider regenerates routes.yml
```

## Troubleshooting Startup Failures

### Debug Startup Probe Failures

If you see "The user-provided container failed the configured startup probe checks":

```bash
# Run debug script to see detailed logs
cd deploy/traefik
./debug-startup.sh stg
```

This will show:
- Revision status and conditions
- Main Traefik container logs (last 100 lines)
- Provider sidecar logs (last 50 lines)
- Common issues and solutions

### Common Startup Issues

1. **Traefik not starting**:
   - Check config file errors in logs
   - Verify `/etc/traefik/traefik.yml` is valid YAML
   - Check entrypoint script logs for errors

2. **`/ping` endpoint not responding**:
   - Verify Traefik is listening on port 8080
   - Check if Traefik process is running
   - Look for port binding errors in logs

3. **Shared volume issues**:
   - Verify volume mounts are configured correctly
   - Check if `/shared/traefik/dynamic` exists and is writable
   - Look for permission errors in entrypoint logs

4. **Provider not generating routes**:
   - Check provider logs for IAM permission errors
   - Verify environment variables are set correctly
   - Check if provider can access Cloud Run API

## Troubleshooting

### Provider Not Generating Routes

```bash
# Check provider logs for errors
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=provider \
  --limit=100

# Common issues:
# - Missing LABS_PROJECT_ID environment variable
# - Insufficient IAM permissions (needs roles/run.viewer)
# - Network issues accessing Cloud Run API
```

### Main Traefik Not Reading Routes

```bash
# Check main Traefik logs
gcloud run services logs read traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --container=traefik \
  --limit=100

# Common issues:
# - File provider not watching /shared/traefik/dynamic
# - routes.yml not generated yet (wait for provider)
# - YAML syntax errors in routes.yml
```

### Dashboard Not Accessible

```bash
# Check dashboard logs
gcloud run services logs read traefik-dashboard-stg \
  --region=us-central1 \
  --project=labs-stg \
  --limit=100

# Check TRAEFIK_API_URL environment variable
gcloud run services describe traefik-dashboard-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="yaml(spec.template.spec.containers[0].env)"

# Common issues:
# - TRAEFIK_API_URL not set correctly
# - Main Traefik service not accessible
# - Network connectivity issues
```

### Service Not Starting

```bash
# Check service status
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="yaml(status.conditions)"

# Check for:
# - Ready condition should be True
# - Any error conditions
```

## Quick Test Script

Save this as `test-deployment.sh`:

```bash
#!/bin/bash
set -e

ENVIRONMENT="${1:-stg}"
PROJECT_ID="labs-${ENVIRONMENT}"
REGION="us-central1"

echo "🧪 Testing Traefik Sidecar Deployment (${ENVIRONMENT})"
echo ""

# Get URLs
MAIN_URL=$(gcloud run services describe traefik-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --format="value(status.url)")

DASHBOARD_URL=$(gcloud run services describe traefik-dashboard-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --format="value(status.url)")

echo "📋 Service URLs:"
echo "   Main Traefik: ${MAIN_URL}"
echo "   Dashboard: ${DASHBOARD_URL}"
echo ""

# Test 1: Main Traefik health check
echo "1️⃣  Testing main Traefik health check..."
if curl -sf "${MAIN_URL}/ping" > /dev/null; then
  echo "   ✅ Main Traefik is healthy"
else
  echo "   ❌ Main Traefik health check failed"
  exit 1
fi

# Test 2: Provider logs
echo "2️⃣  Checking provider sidecar logs..."
PROVIDER_LOGS=$(gcloud run services logs read traefik-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --container=provider \
  --limit=10 \
  --format="value(textPayload)" 2>/dev/null || echo "")

if echo "${PROVIDER_LOGS}" | grep -qi "routes.*generated\|starting.*provider"; then
  echo "   ✅ Provider is generating routes"
else
  echo "   ⚠️  Provider logs not found or no route generation detected"
fi

# Test 3: Dashboard accessibility
echo "3️⃣  Testing dashboard accessibility..."
if curl -sf "${DASHBOARD_URL}/dashboard/" > /dev/null; then
  echo "   ✅ Dashboard is accessible"
else
  echo "   ⚠️  Dashboard may require authentication or is not ready"
fi

# Test 4: Main Traefik logs
echo "4️⃣  Checking main Traefik logs..."
TRAEFIK_LOGS=$(gcloud run services logs read traefik-${ENVIRONMENT} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --container=traefik \
  --limit=10 \
  --format="value(textPayload)" 2>/dev/null || echo "")

if echo "${TRAEFIK_LOGS}" | grep -qi "configuration.*loaded\|file provider"; then
  echo "   ✅ Main Traefik is running and watching routes"
else
  echo "   ⚠️  Main Traefik logs not found or configuration not loaded"
fi

echo ""
echo "✅ Basic tests completed!"
echo ""
echo "💡 Next steps:"
echo "   - Check detailed logs: gcloud run services logs read traefik-${ENVIRONMENT} --region=${REGION} --project=${PROJECT_ID}"
echo "   - Test routing: curl -H 'Authorization: Bearer \$(gcloud auth print-identity-token)' ${MAIN_URL}/"
echo "   - View dashboard: ${DASHBOARD_URL}/dashboard/"
```

Make it executable and run:
```bash
chmod +x test-deployment.sh
./test-deployment.sh stg
```

## Expected Results

### Successful Deployment

1. **Main Traefik Service**:
   - Status: Ready
   - Health check: `/ping` returns 200 OK
   - Logs show: "Configuration loaded", "file provider watching"

2. **Provider Sidecar**:
   - Logs show: "Starting traefik-cloudrun-provider"
   - Logs show: "Routes file generated"
   - Logs show: Summary of routers and services

3. **Dashboard Service**:
   - Status: Ready
   - Dashboard accessible at `/dashboard/`
   - API proxy working (proxies to main Traefik)

### Common Issues

- **Provider not starting**: Check IAM permissions, environment variables
- **Routes not updating**: Check provider logs, verify Cloud Run service labels
- **Dashboard 404**: Check TRAEFIK_API_URL, verify main Traefik is accessible
- **Service crashes**: Check resource limits, logs for errors
