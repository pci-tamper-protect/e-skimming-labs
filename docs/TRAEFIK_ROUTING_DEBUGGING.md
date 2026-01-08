# Traefik Routing Debugging Guide

This guide provides step-by-step instructions for debugging Traefik routing issues, with a focus on 502 Bad Gateway errors.

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
1. Verify service labels in `docker-compose.yml`
2. Check service is running: `docker-compose ps`
3. Restart Traefik: `docker-compose restart traefik`
4. For Cloud Run: Check environment variables are set correctly

---

### Issue: 502 Bad Gateway

**Symptoms:** Traefik returns 502 when accessing a service

**This is the most common routing issue. Follow these steps systematically:**

#### Step 0: Verify Proxy is Running (Staging)

**Before debugging, ensure the staging proxy is running:**

```bash
# Check if proxy is running on expected port
lsof -i :8082 | grep LISTEN

# Or check for gcloud proxy process
ps aux | grep "gcloud run services proxy"

# If not running, start it:
./deploy/traefik/proxy-traefik-stg.sh

# Or manually:
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8082
```

**If proxy is not running:**
- Start the proxy first before debugging
- Check `.env.stg` has `STG_PROXY_PORT=8082` set
- Verify you're authenticated: `gcloud auth list`

#### Step 1: Verify Backend Service is Running

```bash
# For Docker Compose (local)
docker-compose ps
docker-compose logs lab1-vulnerable-site

# For Cloud Run (staging) - requires gcloud
gcloud run services describe lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="value(status.conditions[0].status)"

# Check service is ready (should return "True")

# Alternative: Check via proxy if running
curl -s http://127.0.0.1:8082/api/http/services | jq -r '.[] | select(.name | contains("lab1")) | .name'
```

**If service is not running:**
- Restart the service: `docker-compose restart lab1-vulnerable-site`
- For Cloud Run: Check deployment logs for errors
- Verify service name is correct (may vary by deployment)

#### Step 2: Test Backend Service Directly

```bash
# For Docker Compose
docker exec lab1-techgear-store wget -O- http://localhost:80

# For Cloud Run - test with identity token
TOKEN=$(gcloud auth print-identity-token --audience="https://lab-01-basic-magecart-stg-xxxxx-uc.a.run.app")
curl -H "Authorization: Bearer $TOKEN" https://lab-01-basic-magecart-stg-xxxxx-uc.a.run.app/
```

**If direct access fails:**
- Backend service has an issue (check service logs)
- Service is not listening on expected port
- Service is crashing on startup

#### Step 3: Check Traefik Service Configuration

```bash
# For Docker Compose - check Traefik knows about the service
curl -s http://localhost:8081/api/http/services | jq '.[] | select(.name | contains("lab1"))'

# For Cloud Run via proxy - check Traefik API
curl -s http://127.0.0.1:8082/api/http/services | jq '.[] | select(.name | contains("lab1"))'

# Check service details
curl -s http://127.0.0.1:8082/api/http/services/lab1 | jq '.'

# For Cloud Run - check generated routes (requires gcloud)
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg" \
  --limit=50 \
  --project=labs-stg \
  --format=json | jq -r '.[] | select(.jsonPayload.message | contains("lab1")) | .jsonPayload.message'
```

**Expected output should show:**
- Service name matches (e.g., `lab1` or `lab-01-basic-magecart-stg`)
- Service URL is correct (Cloud Run URL)
- Port is correct (usually 8080 for Cloud Run)
- Load balancer configuration is present

#### Step 4: Verify Router Configuration

```bash
# For Docker Compose
curl -s http://localhost:8081/api/http/routers | jq '.[] | select(.name | contains("lab1"))'

# For Cloud Run via proxy
curl -s http://127.0.0.1:8082/api/http/routers | jq '.[] | select(.name | contains("lab1"))'

# Check specific router (try different router names)
curl -s http://127.0.0.1:8082/api/http/routers | jq -r '.[].name' | grep -i lab1

# Check router details (replace with actual router name from above)
curl -s http://127.0.0.1:8082/api/http/routers/lab1 | jq '.'
curl -s http://127.0.0.1:8082/api/http/routers/lab1-c2 | jq '.'
curl -s http://127.0.0.1:8082/api/http/routers/lab1-static | jq '.'
```

**Check:**
- Router rule matches the path you're accessing (e.g., `PathPrefix(\`/lab1\`)`)
- Router priority is correct (higher priority routes first)
- Router service name matches the service name
- Router has middlewares configured (especially auth middleware for Cloud Run)

#### Step 5: Check Middleware Configuration (Cloud Run - Authentication)

**For Cloud Run services, 502 often means authentication failed:**

```bash
# Check if auth middleware is configured via Traefik API
curl -s http://127.0.0.1:8082/api/http/middlewares | jq -r '.[].name' | grep -i "lab1.*auth"

# Check middleware details
curl -s http://127.0.0.1:8082/api/http/middlewares | jq '.[] | select(.name | contains("lab1-auth"))'

# Verify router uses auth middleware
curl -s http://127.0.0.1:8082/api/http/routers | jq '.[] | select(.name | contains("lab1")) | {name, middlewares}'

# Check Traefik logs for token generation (requires gcloud)
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND jsonPayload.message=~\"Token\"" \
  --limit=20 \
  --project=labs-stg \
  --format=json | jq -r '.[].jsonPayload.message'

# Check if identity tokens are being generated
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND jsonPayload.message=~\"LAB1_TOKEN\"" \
  --limit=10 \
  --project=labs-stg
```

**Common issues:**
- Identity token not generated (check Traefik service account permissions)
- Auth middleware not added to router (check `generate-routes-from-labels.sh`)
- Token expired or invalid
- Router doesn't include auth middleware in middleware list

#### Step 6: Verify IAM Permissions (Cloud Run)

```bash
# Check Traefik service account has invoker role on backend
gcloud run services get-iam-policy lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg | grep traefik-stg@labs-stg.iam.gserviceaccount.com

# Check backend service is private (should NOT have allUsers)
gcloud run services get-iam-policy lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg | grep allUsers

# Verify Traefik service account exists and has correct permissions
gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:traefik-stg@labs-stg.iam.gserviceaccount.com"
```

**Required permissions:**
- Traefik service account needs `roles/run.invoker` on backend services
- Backend services should NOT have `allUsers` binding (must be private)

#### Step 7: Check Backend Service Logs

```bash
# For Docker Compose
docker-compose logs lab1-vulnerable-site --tail=50

# For Cloud Run
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=lab-01-basic-magecart-stg" \
  --limit=50 \
  --project=labs-stg \
  --format=json | jq -r '.[] | "\(.timestamp) \(.jsonPayload.message // .textPayload)"'
```

**Look for:**
- Authentication errors (403, 401)
- Service startup errors
- Request handling errors
- Missing environment variables

#### Step 8: Test with Identity Token Manually

```bash
# Get identity token for backend service
BACKEND_URL="https://lab-01-basic-magecart-stg-xxxxx-uc.a.run.app"
TOKEN=$(gcloud auth print-identity-token --audience="$BACKEND_URL")

# Test direct access
curl -v -H "Authorization: Bearer $TOKEN" "$BACKEND_URL/"

# Test specific path (e.g., /c2)
curl -v -H "Authorization: Bearer $TOKEN" "$BACKEND_URL/c2"
```

**If this works but Traefik doesn't:**
- Traefik is not generating/forwarding the token correctly
- Check `generate-routes-from-labels.sh` creates auth middleware
- Verify router uses the auth middleware

#### Step 9: Verify Route Generation (Cloud Run)

```bash
# Test route generation script locally
cd deploy/traefik
ENVIRONMENT=stg \
  LABS_PROJECT_ID=labs-stg \
  HOME_PROJECT_ID=labs-home-stg \
  REGION=us-central1 \
  ./generate-routes-from-labels.sh /tmp/test-routes.yml

# Check generated routes
cat /tmp/test-routes.yml | grep -A 10 "lab1"

# Verify auth middleware is created and added to routers
cat /tmp/test-routes.yml | grep -A 3 "lab1-auth"
cat /tmp/test-routes.yml | grep -B 2 -A 5 "lab1:" | grep "middlewares"
```

**Check:**
- Routes are generated correctly
- Auth middleware is created (`lab1-auth:`)
- Routers include auth middleware in their middleware list
- Service URLs are correct

#### Step 10: Check Traefik Entrypoint Script

```bash
# Test entrypoint script locally
cd deploy/traefik
./test-entrypoint.sh stg

# Check generated configuration
cat test-output/dynamic/routes.yml | grep -A 10 "lab1"
```

**Common issues:**
- Environment variables not set in Cloud Run
- Token generation failing silently
- Routes not being generated from labels

---

### 502 Error Patterns and Solutions

#### Pattern 1: Service Not Running
**Symptoms:** 502 immediately, no backend logs
**Solution:** Start/restart the service

#### Pattern 2: Authentication Failure
**Symptoms:** 502 with backend logs showing 403/401
**Solution:** 
- Check IAM permissions
- Verify identity tokens are generated
- Ensure auth middleware is added to router

#### Pattern 3: Wrong Port
**Symptoms:** 502, backend logs show connection refused
**Solution:** 
- Verify service port matches Traefik configuration
- Check `traefik_http_services_*_loadbalancer_server_port` label

#### Pattern 4: Service Crashes on Request
**Symptoms:** 502, backend logs show crash/error
**Solution:** 
- Check backend service logs for errors
- Verify environment variables are set
- Check service dependencies

#### Pattern 5: Cold Start Timeout
**Symptoms:** 502 on first request, works on retry
**Solution:** 
- Increase Traefik timeout
- Add retry middleware
- Pre-warm services

#### Pattern 6: Route Not Matching
**Symptoms:** 502, but different route works
**Solution:** 
- Check router rule matches path
- Verify router priority
- Check for conflicting routes

---

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

---

### Issue: Static Assets Not Loading

**Symptoms:** HTML loads but CSS/JS fails

**Solutions:**
1. Check if `stripPrefix` middleware is correctly configured
2. Verify paths in HTML are relative (not absolute)
3. Update asset paths: `/css/style.css` → `css/style.css`
4. Check browser console for errors

---

### Issue: Infinite Redirects

**Symptoms:** Browser shows "too many redirects"

**Solutions:**
1. Check if multiple middlewares are adding redirects
2. Verify `X-Forwarded-Proto` header handling
3. Disable HTTP to HTTPS redirect in local development
4. Check Cloud Run ingress settings

---

## Quick Reference: 502 Debugging Checklist

- [ ] **Proxy is running** (for staging: check port 8082)
- [ ] Backend service is running
- [ ] Backend service is accessible directly (with auth token for Cloud Run)
- [ ] Traefik knows about the service (check `/api/http/services` via proxy)
- [ ] Router is configured correctly (check `/api/http/routers` via proxy)
- [ ] Router points to correct service
- [ ] Router rule matches the path being accessed
- [ ] Middleware is configured (for Cloud Run: auth middleware exists)
- [ ] Router uses auth middleware (for Cloud Run - check middleware list)
- [ ] IAM permissions are correct (Traefik can invoke backend)
- [ ] Backend service is private (no `allUsers`)
- [ ] Identity tokens are being generated (check Traefik logs)
- [ ] Service port matches configuration (usually 8080 for Cloud Run)
- [ ] Route generation script works correctly (test locally)
- [ ] Backend service logs show no errors
- [ ] No conflicting routes (check router priorities)

---

## Related Documentation

- **[docs/STAGING.md](STAGING.md)** - Staging environment setup
- **[docs/TESTING_TROUBLESHOOTING.md](TESTING_TROUBLESHOOTING.md)** - General troubleshooting
- **[deploy/traefik/README.md](../deploy/traefik/README.md)** - Traefik configuration
- **[deploy/traefik/generate-routes-from-labels.sh](../deploy/traefik/generate-routes-from-labels.sh)** - Route generation script

---

**Last Updated:** 2026-01-08  
**Version:** 1.0
