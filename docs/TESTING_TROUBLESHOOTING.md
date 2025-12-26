# Testing & Troubleshooting Guide

Complete guide for testing and troubleshooting gcloud services and Traefik routing updates.

---

## 📚 Related Documentation

- **[Environment Testing Guide](./test/ENVIRONMENT_TESTING.md)** - Testing across local/staging/production
- **[Staging Guide](./STAGING.md)** - Complete staging environment setup
- **[Traefik Architecture](./TRAEFIK-ARCHITECTURE.md)** - Architecture and troubleshooting
- **[Traefik Router Setup](../deploy/TRAEFIK_ROUTER_SETUP.md)** - Cloud Run deployment details
- **[Traefik Testing](../deploy/traefik/TESTING.md)** - Local entrypoint.sh testing

---

## 🔄 GitHub Workflows

### Related Workflows

1. **[`.github/workflows/deploy_labs.yml`](../.github/workflows/deploy_labs.yml)**
   - Deploys all lab services and home components
   - Includes E2E tests with Traefik proxy for staging
   - Triggers: Push to `main`/`stg` branches, PRs
   - Manual trigger: `gh workflow run deploy_labs.yml -f environment=stg|prd`

2. **[`.github/workflows/test.yml`](../.github/workflows/test.yml)**
   - Runs E2E tests with parallel sharding
   - Supports local, staging, and production environments

### Viewing Workflow Runs

```bash
# List recent workflow runs
gh run list --workflow=deploy_labs.yml

# View specific run
gh run view <run-id>

# Watch a running workflow
gh run watch <run-id>
```

### Traefik Deployment

**Note:** Traefik is deployed manually using the build-and-push script, not via GitHub Actions workflow.

```bash
# Build and push Traefik image
cd deploy/traefik
./build-and-push.sh [stg|prd]

# Then deploy via gcloud (or use Terraform)
gcloud run deploy traefik-stg \
  --image=us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik:latest \
  --region=us-central1 \
  --project=labs-stg
```

---

## 🧪 Testing Traefik Locally

### Test entrypoint.sh Configuration

Before deploying to Cloud Run, test the Traefik configuration generation locally:

```bash
cd deploy/traefik
./test-entrypoint.sh [local|stg|prd]
```

**What it tests:**
- ✅ Token fetching logic (mocked)
- ✅ YAML generation
- ✅ Token escaping
- ✅ Middleware creation
- ✅ Router middleware assignment
- ✅ YAML syntax validation

**Output:**
- `test-output/dynamic/cloudrun-services.yml` - Generated config
- `test-output/test-output.log` - Full test output

See **[deploy/traefik/TESTING.md](../deploy/traefik/TESTING.md)** for details.

### Test Local Routing

```bash
# Start services with Traefik
docker-compose up -d

# Test routes
curl http://localhost:8080/
curl http://localhost:8080/lab1
curl http://localhost:8080/lab2
curl http://localhost:8080/lab3

# Check Traefik dashboard
open http://localhost:8081/dashboard/

# View registered services
curl http://localhost:8081/api/http/services | jq

# View routers
curl http://localhost:8081/api/http/routers | jq
```

---

## ☁️ Testing Cloud Run Services

### Verify Service Deployment

```bash
# Check service status
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="table(status.conditions[0].type,status.conditions[0].status,status.url)"

# Check service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg" \
  --limit=50 \
  --project=labs-stg \
  --format=json | jq
```

### Test Service Health

```bash
# Test health endpoint
SERVICE_URL=$(gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format='value(status.url)')

curl -f "${SERVICE_URL}/ping"
```

### Verify Service Account Permissions

```bash
# Run verification script
cd deploy/traefik
./verify_traefik_permissions.sh

# Or manually check
gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:traefik-stg@labs-stg.iam.gserviceaccount.com"
```

---

## 🔍 Troubleshooting Traefik Routing

### Issue: 404 Not Found

**Symptoms:** Accessing a route returns 404

**Diagnosis:**
```bash
# Check if service is registered in Traefik
curl http://localhost:8081/api/http/services | jq '.[] | select(.name | contains("lab1"))'

# Check Traefik logs
docker-compose logs traefik | grep "lab1"

# Verify service is running
docker-compose ps
```

**Solutions:**
1. Verify service labels in `docker-compose.traefik.yml`
2. Check service is running: `docker-compose ps`
3. Restart Traefik: `docker-compose restart traefik`
4. For Cloud Run: Check environment variables are set correctly

### Issue: 502 Bad Gateway

**Symptoms:** Traefik returns 502 when accessing a service

**Diagnosis:**
```bash
# Check backend service logs
docker-compose logs lab1-vulnerable-site

# Test backend directly
docker exec lab1-techgear-store wget -O- http://localhost:80

# For Cloud Run: Check backend service status
gcloud run services describe lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg
```

**Solutions:**
1. Verify backend service is running and healthy
2. Check service port matches Traefik configuration
3. For Cloud Run: Verify service account has `roles/run.invoker` permission
4. Check backend service logs for errors

### Issue: Traefik Can't Reach Backend Services (Cloud Run)

**Symptoms:** 502 errors, authentication failures

**Diagnosis:**
```bash
# Check Traefik service account permissions
gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:traefik-stg@labs-stg.iam.gserviceaccount.com"

# Check backend service IAM policy
gcloud run services get-iam-policy home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg | grep traefik

# Verify backend is private (no allUsers)
gcloud run services get-iam-policy home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg | grep allUsers
```

**Solutions:**
1. Ensure Traefik service account has `roles/run.invoker` on backend services
2. Verify backend services are private (no `allUsers` binding)
3. Check identity tokens are being generated correctly (see [Troubleshooting Authentication](#-troubleshooting-authentication))

### Issue: Static Assets Not Loading

**Symptoms:** HTML loads but CSS/JS fails

**Solutions:**
1. Check if `stripPrefix` middleware is correctly configured
2. Verify paths in HTML are relative (not absolute)
3. Update asset paths: `/css/style.css` → `css/style.css`
4. Check browser console for errors

### Issue: Infinite Redirects

**Symptoms:** Browser shows "too many redirects"

**Solutions:**
1. Check if multiple middlewares are adding redirects
2. Verify `X-Forwarded-Proto` header handling
3. Disable HTTP to HTTPS redirect in local development
4. Check Cloud Run ingress settings

---

## 🔐 Troubleshooting Authentication

### Issue: 403 Forbidden When Accessing Staging

**Symptoms:** Getting "Forbidden" error when accessing `https://labs.stg.pcioasis.com`

**Diagnosis:**
```bash
# Check your group membership
gcloud identity groups memberships check-transitive-membership \
  --group-email="2025-interns@pcioasis.com" \
  --member-email="your-email@pcioasis.com"

# Check Traefik IAM bindings
gcloud run services get-iam-policy traefik-stg \
  --region=us-central1 \
  --project=labs-stg
```

**Solutions:**

1. **Use gcloud proxy (Recommended):**
   ```bash
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8081
   ```
   Then access `http://127.0.0.1:8081`

2. **Add your user directly:**
   ```bash
   cd deploy/terraform-home
   ./add-user-access.sh your-email@pcioasis.com
   ```

3. **Verify group membership:**
   - Ensure you're in `group:2025-interns@pcioasis.com` or `group:core-eng@pcioasis.com`
   - Contact Google Workspace admin to add you

See **[deploy/terraform-home/ACCESS_TROUBLESHOOTING.md](../deploy/terraform-home/ACCESS_TROUBLESHOOTING.md)** for details.

### Issue: Authentication Headers Not Being Sent

**Symptoms:** Backend services return 403, logs show "NO AUTH HEADER"

**Diagnosis:**
```bash
# Check Traefik logs for token generation
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND jsonPayload.message=~\"Token\"" \
  --limit=20 \
  --project=labs-stg

# Check if middleware is configured
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND jsonPayload.message=~\"Auth Middlewares\"" \
  --limit=10 \
  --project=labs-stg
```

**Solutions:**
1. Test entrypoint.sh locally: `cd deploy/traefik && ./test-entrypoint.sh stg`
2. Verify environment variables are set in Cloud Run service
3. Check that `entrypoint.sh` is generating auth middlewares correctly
4. Rebuild and redeploy Traefik image

---

## 🌐 Troubleshooting Domain & DNS

### Issue: Domain Not Pointing to Traefik

**Symptoms:** `labs.stg.pcioasis.com` doesn't resolve or points to wrong service

**Diagnosis:**
```bash
# Check domain mapping
gcloud run domain-mappings describe labs.stg.pcioasis.com \
  --region=us-central1 \
  --project=labs-stg

# Verify DNS records
dig labs.stg.pcioasis.com
```

**Solutions:**
1. **Update domain mapping:**
   ```bash
   # Delete old mapping
   gcloud run domain-mappings delete labs.stg.pcioasis.com \
     --region=us-central1 \
     --project=labs-stg

   # Create new mapping to Traefik
   gcloud run domain-mappings create labs.stg.pcioasis.com \
     --region=us-central1 \
     --project=labs-stg \
     --service=traefik-stg
   ```

2. **Check Cloudflare DNS settings** (if using Cloudflare)

### Issue: localhost vs 127.0.0.1 Proxy Access

**Symptoms:** `http://localhost:8081` gives 404, but `http://127.0.0.1:8081` works

**Solution:**
This is an IPv6/IPv4 resolution issue. Use `127.0.0.1` or use the helper script:

```bash
cd deploy/traefik
./proxy-traefik-stg.sh 8081
```

---

## 🧪 Testing After Updates

### After Updating Traefik Configuration

1. **Test locally:**
   ```bash
   cd deploy/traefik
   ./test-entrypoint.sh stg
   ```

2. **Rebuild and push image:**
   ```bash
   cd deploy/traefik
   ./build-and-push.sh stg
   ```

3. **Build and push image:**
   ```bash
   cd deploy/traefik
   ./build-and-push.sh stg
   ```

4. **Or deploy manually:**
   ```bash
   gcloud run deploy traefik-stg \
     --image=us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik:latest \
     --region=us-central1 \
     --project=labs-stg
   ```

5. **Restart proxy (if using):**
   ```bash
   pkill -f "gcloud run services proxy"
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8081
   ```

6. **Verify deployment:**
   ```bash
   curl -f http://127.0.0.1:8081/ping
   ```

### After Updating Home Index Service

1. **Deploy service:**
   ```bash
   cd deploy/shared-components/home-index-service
   ./deploy-stg-simple.sh
   ```

2. **Restart proxy** (if using):
   ```bash
   pkill -f "gcloud run services proxy"
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8081
   ```

3. **Test navigation:**
   - Home page loads
   - Links use relative URLs (when accessed via proxy)
   - Navigation between pages works

### After Updating Lab Services

1. **Deploy via GitHub Actions:**
   ```bash
   gh workflow run deploy_labs.yml -f environment=stg
   ```

2. **Or deploy specific lab:**
   ```bash
   # Check deploy_labs.yml for specific lab deployment commands
   ```

3. **Test lab functionality:
   - Lab loads correctly
   - C2 server accessible
   - Navigation works

---

## 📊 Monitoring & Logs

### View Traefik Logs

```bash
# Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg" \
  --limit=50 \
  --project=labs-stg \
  --format=json | jq

# Filter for specific routes
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND jsonPayload.RequestPath=~\"/lab1\"" \
  --limit=20 \
  --project=labs-stg

# Filter for auth issues
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND (jsonPayload.message=~\"Token\" OR jsonPayload.message=~\"Auth\")" \
  --limit=20 \
  --project=labs-stg
```

### View Backend Service Logs

```bash
# Home index service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=home-index-stg" \
  --limit=50 \
  --project=labs-home-stg

# Lab service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=lab-01-basic-magecart-stg" \
  --limit=50 \
  --project=labs-stg
```

### Check Service Metrics

```bash
# Open Cloud Console
open "https://console.cloud.google.com/run/detail/us-central1/traefik-stg/metrics?project=labs-stg"
```

---

## 🧪 E2E Testing

### Running E2E Tests

```bash
# Local environment
cd test
TEST_ENV=local npm test

# Staging environment (uses proxy automatically in CI)
cd test
TEST_ENV=stg npm test

# Production environment
cd test
TEST_ENV=prd npm test
```

### Staging E2E Tests with Proxy

The GitHub Actions workflow automatically:
1. Starts `gcloud run services proxy` for Traefik
2. Sets `PROXY_URL` and `USE_PROXY` environment variables
3. Runs tests against the proxy
4. Cleans up proxy after tests

See **[docs/STAGING_E2E_PROXY.md](./STAGING_E2E_PROXY.md)** for details.

### Manual E2E Testing with Proxy

```bash
# Start proxy in background
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8081 &

# Run tests
cd test
export PROXY_URL="http://127.0.0.1:8081"
export USE_PROXY="true"
export TEST_ENV="stg"
npm test

# Stop proxy
pkill -f "gcloud run services proxy"
```

---

## 🔧 Quick Reference Commands

### Service Status

```bash
# List all Cloud Run services
gcloud run services list --project=labs-stg --region=us-central1

# Describe specific service
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg

# Get service URL
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format='value(status.url)'
```

### IAM Permissions

```bash
# Check service IAM policy
gcloud run services get-iam-policy traefik-stg \
  --region=us-central1 \
  --project=labs-stg

# Check project-level IAM
gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:traefik-stg@labs-stg.iam.gserviceaccount.com"
```

### Proxy Commands

```bash
# Start proxy
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8081

# Stop proxy
pkill -f "gcloud run services proxy"

# Check if proxy is running
ps aux | grep "gcloud run services proxy"
```

### Testing Routes

```bash
# Test health endpoint
curl http://127.0.0.1:8081/ping

# Test home page
curl http://127.0.0.1:8081/

# Test lab routes
curl http://127.0.0.1:8081/lab1
curl http://127.0.0.1:8081/lab2
curl http://127.0.0.1:8081/lab3
```

---

## 📝 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| 404 on routes | Check service labels, restart Traefik |
| 502 Bad Gateway | Verify backend service is running, check IAM permissions |
| 403 Forbidden | Use proxy or add user to IAM groups |
| Auth headers missing | Test entrypoint.sh, rebuild image |
| Domain not resolving | Check domain mapping, DNS records |
| localhost vs 127.0.0.1 | Use 127.0.0.1 or helper script |
| Changes not reflected | Restart proxy after deployment |

---

## 🔗 Additional Resources

- **[Traefik Official Docs](https://doc.traefik.io/traefik/)**
- **[Cloud Run Troubleshooting](https://cloud.google.com/run/docs/troubleshooting)**
- **[gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference)**

---

## 🆘 Getting Help

1. Check logs first (see [Monitoring & Logs](#-monitoring--logs))
2. Review related documentation (see [Related Documentation](#-related-documentation))
3. Check GitHub workflow runs for deployment issues
4. Open a GitHub issue with:
   - Error messages
   - Relevant logs
   - Steps to reproduce
   - Environment (local/staging/production)
