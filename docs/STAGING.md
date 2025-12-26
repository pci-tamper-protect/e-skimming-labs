# Staging Environment Guide

Complete guide for setting up, testing, and running E2E tests against the staging environment (`labs.stg.pcioasis.com`).

---

## 🎯 Overview

The staging environment is a pre-production deployment used for:
- **Testing** new features before production
- **E2E Testing** automated test suites
- **Development** testing with real Cloud Run infrastructure
- **Integration Testing** with other staging services

**Staging URL:** `https://labs.stg.pcioasis.com`

---

## 🔐 Access & Authentication

### Browser Access

Staging requires Google IAM authentication. To access in your browser:

1. **Sign in to Google** with your authorized account:
   - Go to: https://myaccount.google.com
   - Ensure you're signed in with an account that has access

2. **Access the domain:**
   - Navigate to: `https://labs.stg.pcioasis.com`
   - You'll be redirected to Google sign-in if not authenticated
   - After signing in, you should have access

3. **If you get "403 Forbidden":**
   - Verify you're signed in with the correct Google account
   - Check that your account is in one of these groups:
     - `2025-interns@pcioasis.com`
     - `core-eng@pcioasis.com`
   - Clear browser cache/cookies for `labs.stg.pcioasis.com`
   - Try incognito/private browsing mode

### Proxy Access (Recommended for Development)

For local development and testing, use the `gcloud run services proxy` command:

```bash
# Start the proxy (handles authentication automatically)
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8081
```

**Access via proxy:**
- ✅ `http://127.0.0.1:8081` (always works)
- ⚠️ `http://localhost:8081` (may give 404 due to IPv6/IPv4 mismatch)

**Why use the proxy?**
- No browser authentication required
- Faster iteration during development
- Works with relative URLs (see below)

**Important:** After deploying changes to Traefik or home-index-service, **you must restart the proxy** to see the changes:

```bash
# Stop the proxy (Ctrl+C or kill the process)
pkill -f "gcloud run services proxy"

# Restart it
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8081
```

---

## 🧪 Manual Testing

### Testing via Browser (Direct Domain Access)

1. **Sign in to Google** (see [Access & Authentication](#-access--authentication) above)
2. **Navigate to staging:**
   ```
   https://labs.stg.pcioasis.com
   ```
3. **Test navigation:**
   - Home page loads correctly
   - Click "MITRE ATT&CK" → should go to `/mitre-attack`
   - Click "Threat Model" → should go to `/threat-model`
   - Click lab links → should navigate to lab pages
   - Test "Back to Labs" buttons on lab pages

### Testing via Proxy (Recommended)

1. **Start the proxy:**
   ```bash
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8081
   ```

2. **Access via proxy:**
   ```
   http://127.0.0.1:8081
   ```

3. **Test navigation:**
   - All links should use relative URLs (stay within proxy)
   - Navigation should work without browser authentication
   - Test all lab pages and C2 dashboards

4. **After deploying changes:**
   - **Restart the proxy** (see [Important Note](#-important-restart-proxy-after-changes))

---

## 🚀 Deploying to Staging

### Deploy home-index-service

```bash
cd /Users/kestenbroughton/projectos/e-skimming-labs
./deploy/shared-components/home-index-service/deploy-stg.sh
```

Or manually:

```bash
# 1. Authenticate
gcloud auth configure-docker us-central1-docker.pkg.dev

# 2. Build
IMAGE_TAG=$(git rev-parse --short HEAD)
docker build \
  -f deploy/shared-components/home-index-service/Dockerfile \
  --build-arg ENVIRONMENT=stg \
  -t us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:${IMAGE_TAG} \
  .

# 3. Push
docker push us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:${IMAGE_TAG}

# 4. Deploy
gcloud run deploy home-index-stg \
  --image=us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:${IMAGE_TAG} \
  --region=us-central1 \
  --project=labs-home-stg \
  --no-allow-unauthenticated \
  --service-account=home-runtime-sa@labs-home-stg.iam.gserviceaccount.com \
  --port=8080 \
  --set-env-vars="ENVIRONMENT=stg,DOMAIN=labs.stg.pcioasis.com,LABS_DOMAIN=labs.stg.pcioasis.com,MAIN_DOMAIN=pcioasis.com,LABS_PROJECT_ID=labs-stg" \
  --update-secrets=/etc/secrets/dotenvx-key=DOTENVX_KEY_STG:latest
```

**After deployment:**
- ✅ Restart the proxy to see changes
- ✅ Test in browser (direct domain access)
- ✅ Verify navigation works correctly

### Deploy Traefik

Traefik is typically deployed via GitHub Actions workflow, but can be deployed manually:

```bash
cd deploy/traefik
./build-and-push.sh stg

# Then apply Terraform (if needed)
cd ../terraform-labs
terraform apply -var="environment=stg"
```

**After deployment:**
- ✅ Restart the proxy to see changes
- ✅ Verify routing works correctly

---

## 🧪 E2E Testing

### Prerequisites

1. **Test account setup** (see [test/AUTH_SETUP.md](../test/AUTH_SETUP.md)):
   - Test account: `labs.test+1@pcioasis.com`
   - Encrypted credentials: `.env.tests.stg`

2. **Environment variables:**
   ```bash
   export TEST_ENV=stg
   export AUTH_ENABLED=true
   export TEST_USER_EMAIL_STG=labs.test+1@pcioasis.com
   export TEST_USER_PASSWORD_STG=<password>
   ```

### Running E2E Tests

#### Option 1: Run All E2E Tests

```bash
cd test
TEST_ENV=stg npm test
```

#### Option 2: Run Specific Test Suites

```bash
cd test

# Global navigation tests
TEST_ENV=stg npx playwright test e2e/global-navigation.spec.js

# Authentication tests
TEST_ENV=stg npx playwright test e2e/auth-stg.spec.js

# MITRE ATT&CK tests
TEST_ENV=stg npx playwright test e2e/mitre-attack-matrix.spec.js

# Threat model tests
TEST_ENV=stg npx playwright test e2e/threat-model.spec.js
```

#### Option 3: Run with Authentication (Automatic)

The test suite automatically handles authentication when `TEST_ENV=stg`:
- Global setup (`test/utils/global-setup-auth.js`) runs once
- Authenticates with test account
- Saves auth state to `test/.auth/storage-state.json`
- All tests reuse the auth state

### Test Configuration

Tests use `test/config/test-env.js` for environment URLs:

```javascript
stg: {
  homeIndex: 'https://labs.stg.pcioasis.com',
  mainApp: 'https://stg.pcioasis.com',
  firebaseProjectId: 'ui-firebase-pcioasis-stg',
  // ... lab URLs
}
```

### Troubleshooting E2E Tests

**Tests fail with "403 Forbidden":**
- Verify test account exists in Firebase
- Check credentials are correct in `.env.tests.stg`
- Ensure `AUTH_ENABLED=true` is set
- Check that global setup ran successfully

**Tests fail with "Authentication required":**
- Verify `test/.auth/storage-state.json` exists
- Delete it and rerun tests (will regenerate)
- Check that test account has access to staging

**Tests timeout:**
- Check staging services are running
- Verify network connectivity
- Increase timeout in `test/playwright.config.js`

---

## 🔄 Important: Restart Proxy After Changes

**⚠️ CRITICAL:** After deploying changes to Traefik or home-index-service, you **must restart the proxy** to see the changes.

### Why?

The `gcloud run services proxy` command creates a local proxy connection to the Cloud Run service. When you deploy a new version:
- The Cloud Run service is updated
- But the proxy maintains a connection to the old version
- Restarting the proxy establishes a new connection to the updated service

### How to Restart

```bash
# Method 1: Stop and restart
pkill -f "gcloud run services proxy"
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8081

# Method 2: Use Ctrl+C if running in foreground
# Then restart with the same command
```

### When to Restart

Restart the proxy after:
- ✅ Deploying home-index-service
- ✅ Deploying Traefik
- ✅ Updating environment variables
- ✅ Changing service configuration
- ✅ After any Cloud Run deployment

### Verify Changes

After restarting:
1. **Hard refresh browser:** `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
2. **Check browser console:** Press F12, look for errors
3. **Test navigation:** Click links to verify they work
4. **Check network tab:** Verify requests go to correct endpoints

---

## 📊 Service URLs

### Staging Services

| Service | URL | Description |
|---------|-----|-------------|
| **Home Index** | `https://labs.stg.pcioasis.com` | Main landing page |
| **MITRE ATT&CK** | `https://labs.stg.pcioasis.com/mitre-attack` | MITRE matrix |
| **Threat Model** | `https://labs.stg.pcioasis.com/threat-model` | Threat model visualization |
| **Lab 1** | `https://labs.stg.pcioasis.com/lab1` | Basic Magecart Attack |
| **Lab 1 C2** | `https://labs.stg.pcioasis.com/lab1/c2` | Lab 1 C2 dashboard |
| **Lab 2** | `https://labs.stg.pcioasis.com/lab2` | DOM-Based Skimming |
| **Lab 2 C2** | `https://labs.stg.pcioasis.com/lab2/c2` | Lab 2 C2 dashboard |
| **Lab 3** | `https://labs.stg.pcioasis.com/lab3` | Extension Hijacking |
| **Lab 3 C2** | `https://labs.stg.pcioasis.com/lab3/extension` | Lab 3 C2 dashboard |

### Proxy URLs (when proxy is running)

| Service | Proxy URL | Description |
|---------|-----------|-------------|
| **Home Index** | `http://127.0.0.1:8081/` | Main landing page |
| **MITRE ATT&CK** | `http://127.0.0.1:8081/mitre-attack` | MITRE matrix |
| **Threat Model** | `http://127.0.0.1:8081/threat-model` | Threat model visualization |
| **Lab 1** | `http://127.0.0.1:8081/lab1` | Basic Magecart Attack |
| **Lab 1 C2** | `http://127.0.0.1:8081/lab1/c2` | Lab 1 C2 dashboard |
| **Lab 2** | `http://127.0.0.1:8081/lab2` | DOM-Based Skimming |
| **Lab 2 C2** | `http://127.0.0.1:8081/lab2/c2` | Lab 2 C2 dashboard |
| **Lab 3** | `http://127.0.0.1:8081/lab3` | Extension Hijacking |
| **Lab 3 C2** | `http://127.0.0.1:8081/lab3/extension` | Lab 3 C2 dashboard |

---

## 🛠️ Troubleshooting

### Proxy Issues

**`localhost:8081` gives 404 but `127.0.0.1:8081` works:**
- This is an IPv6/IPv4 mismatch issue
- Use `127.0.0.1:8081` instead
- Or install `socat` and use the enhanced proxy script:
  ```bash
  ./deploy/traefik/proxy-traefik-stg.sh
  ```

**Proxy shows old version after deployment:**
- Restart the proxy (see [Important: Restart Proxy After Changes](#-important-restart-proxy-after-changes))

**Proxy connection fails:**
- Verify you're authenticated: `gcloud auth list`
- Check service exists: `gcloud run services describe traefik-stg --region=us-central1 --project=labs-stg`
- Verify IAM permissions

### Browser Access Issues

**"403 Forbidden" when accessing domain:**
- Sign in to Google with authorized account
- Verify account is in allowed groups
- Clear browser cache/cookies
- Try incognito mode

**Links navigate to production instead of staging:**
- Check that `DOMAIN` environment variable is set to `labs.stg.pcioasis.com`
- Verify home-index-service was deployed with correct environment variables
- Restart proxy after deployment

### E2E Test Issues

**Tests fail with authentication errors:**
- See [test/AUTH_SETUP.md](../test/AUTH_SETUP.md) for setup instructions
- Verify test account exists in Firebase
- Check credentials in `.env.tests.stg`

**Tests timeout:**
- Check staging services are running
- Verify network connectivity
- Increase timeout in test configuration

---

## 📚 Related Documentation

- **[test/AUTH_SETUP.md](../test/AUTH_SETUP.md)** - E2E test authentication setup
- **[test/ENVIRONMENT_TESTING.md](../test/ENVIRONMENT_TESTING.md)** - General environment testing guide
- **[docs/SETUP.md](SETUP.md)** - Local development setup
- **[docs/TRAEFIK-ARCHITECTURE.md](TRAEFIK-ARCHITECTURE.md)** - Traefik architecture
- **[deploy/shared-components/home-index-service/DEPLOY_INSTRUCTIONS.md](../deploy/shared-components/home-index-service/DEPLOY_INSTRUCTIONS.md)** - Deployment instructions

---

## 🔗 Quick Links

- **Staging URL:** https://labs.stg.pcioasis.com
- **Firebase Console:** https://console.firebase.google.com/project/ui-firebase-pcioasis-stg
- **Cloud Run Console:** https://console.cloud.google.com/run?project=labs-stg
- **Artifact Registry:** https://console.cloud.google.com/artifacts?project=labs-stg

---

**Last Updated:** 2025-12-23  
**Version:** 1.0
