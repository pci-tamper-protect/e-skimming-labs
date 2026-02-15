# Authentication Architecture

This document describes how authentication works across the E-Skimming Labs platform, including the architecture for protecting lab routes while keeping public pages accessible.

## Overview

The authentication system uses:
- **Firebase Authentication** for user authentication (email/password and Google OAuth)
- **Traefik ForwardAuth** middleware to protect lab routes at the reverse proxy level
- **Go middleware** in `home-index-service` to protect lab writeups and validate tokens

## Public vs Protected Routes

### Public Routes (No Authentication Required)

- `/` - Home page
- `/mitre-attack` - MITRE ATT&CK Matrix page
- `/threat-model` - Threat Model page
- `/sign-in` - Sign-in page
- `/sign-up` - Sign-up page
- `/api/auth/*` - Authentication API endpoints
- `/api/labs` - Labs listing API
- `/static/*` - Static assets

### Protected Routes (Authentication Required)

- `/lab1/*` - Lab 1 and all variants (protected by Traefik ForwardAuth)
- `/lab1/c2` - Lab 1 C2 server (protected by Traefik ForwardAuth)
- `/lab2/*` - Lab 2 and C2 server (protected by Traefik ForwardAuth)
- `/lab3/*` - Lab 3 and extension server (protected by Traefik ForwardAuth)
- `/lab-01-writeup` - Lab 1 writeup (protected by Go middleware)
- `/lab-02-writeup` - Lab 2 writeup (protected by Go middleware)
- `/lab-03-writeup` - Lab 3 writeup (protected by Go middleware)

## Architecture Layers

### Layer 1: Traefik ForwardAuth (Lab Routes)

Traefik uses ForwardAuth middleware to protect lab routes (`/lab1`, `/lab2`, `/lab3`) before requests reach the lab containers.

**Configuration:** `deploy/traefik/dynamic/routes.yml`

```yaml
lab1-auth-check:
  forwardAuth:
    address: "http://home-index:8080/api/auth/check"
    authResponseHeaders:
      - "X-User-Id"
      - "X-User-Email"
    authRequestHeaders:
      - "Authorization"
      - "Cookie"
    trustForwardHeader: true
```

**How it works:**
1. User requests `/lab1/`
2. Traefik intercepts the request
3. Traefik forwards to `home-index-service/api/auth/check` to verify authentication
4. If authenticated (200 OK), Traefik forwards the request to the lab container
5. If not authenticated (401/302), Traefik redirects to sign-in page

**Auth Check Endpoint:** `deploy/shared-components/home-index-service/main.go`

The `/api/auth/check` endpoint:
- Extracts token from Authorization header, cookie, or query parameter
- Validates token with Firebase Admin SDK
- Returns 200 OK if authenticated (with user info headers)
- Returns 302 redirect to sign-in for browser requests
- Returns 401 for API requests

### Layer 2: Go Middleware (Lab Writeups)

Lab writeup routes (`/lab-01-writeup`, etc.) are handled by `home-index-service` and protected by Go middleware.

**Configuration:** `deploy/shared-components/home-index-service/auth/middleware.go`

The `AuthMiddleware`:
- Checks if the path is in the public paths list
- If public, allows access without authentication
- If protected, validates Firebase token
- Checks email verification status (if auth is required)
- Redirects unverified users to sign-in

**Email Verification Check:**
```go
// Check email verification if user info is available
if userInfo != nil && validator.IsRequired() && !userInfo.EmailVerified {
    // Redirect to sign-in with error message
    redirectURL := fmt.Sprintf("%s/sign-in?error=email_not_verified&email=%s", 
        validator.GetMainAppURL(), userInfo.Email)
    http.Redirect(w, r, redirectURL, http.StatusFound)
    return
}
```

## Sign-Up Flow with Email Verification

### Step 1: User Signs Up

**File:** `deploy/shared-components/home-index-service/main.go` (serveSignUpPage)

When a user signs up:
1. Firebase creates the account
2. **Verification email is automatically sent** via `userCredential.user.sendEmailVerification()`
3. User sees success message: "Account created! Please check your email to verify your account before signing in."
4. User is redirected to sign-in page after 3 seconds

### Step 2: User Verifies Email

User clicks the verification link in their email, which verifies their Firebase account.

### Step 3: User Signs In

**File:** `deploy/shared-components/home-index-service/main.go` (serveSignInPage)

When signing in:
1. User enters email/password
2. Firebase authenticates
3. **System checks if email is verified**: `if (!userCredential.user.emailVerified)`
4. If not verified:
   - Sends new verification email
   - Shows error: "Please verify your email address. A new verification email has been sent to your inbox."
   - Prevents access to protected routes
5. If verified:
   - User gets ID token
   - Token is stored in sessionStorage
   - User is redirected to the original destination

### Step 4: Accessing Protected Routes

When accessing protected routes:
1. Token is extracted from sessionStorage, cookie, or Authorization header
2. Token is validated with Firebase Admin SDK
3. **Email verification status is checked** from the token claims
4. If not verified, user is redirected to sign-in with error message
5. If verified, access is granted

## Service Account Configuration

### Firebase Admin SDK Runtime Service Account

**Purpose:** Server-side token validation using Firebase Admin SDK

**Terraform:** `deploy/terraform-home/service-accounts.tf`

```terraform
resource "google_service_account" "fbase_adm_sdk_runtime" {
  account_id   = "fbase-adm-sdk-runtime"
  display_name = "Firebase Admin SDK Runtime Service Account"
  description  = "Service account for Firebase Admin SDK operations (token validation)"
}

resource "google_project_iam_member" "fbase_adm_sdk_runtime_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.secretAccessor"  # Access Secret Manager secrets (e.g., DOTENVX_KEY_STG)
  ])
  # ...
}

# Cross-project IAM: Grant Firebase Admin SDK permissions in Firebase project
resource "google_project_iam_member" "fbase_adm_sdk_runtime_firebase_admin" {
  project = local.firebase_project_id
  role    = "roles/firebase.admin"
  member  = "serviceAccount:${google_service_account.fbase_adm_sdk_runtime.email}"
}
```

**Required Permissions:**
- `roles/secretmanager.secretAccessor` - Access `DOTENVX_KEY_STG` from Secret Manager
- `roles/firebase.admin` - Validate Firebase ID tokens in the Firebase project

**Key Management:**
- Service account keys are **NOT** managed by Terraform
- Keys are created using `gcloud` and managed via scripts in `pcioasis-ops/secrets`
- See `docs/FIREBASE_SERVICE_ACCOUNT_SETUP.md` for key creation instructions

## Environment Variables

### Required for Authentication

**Client-side (Firebase Web SDK):**
- `FIREBASE_API_KEY` - Firebase Web API key (semi-secret, client-side)
- `FIREBASE_AUTH_DOMAIN` - Auth domain (e.g., `ui-firebase-pcioasis-stg.firebaseapp.com`)
- `FIREBASE_PROJECT_ID` - Firebase project ID (e.g., `ui-firebase-pcioasis-stg`)

**Server-side (Firebase Admin SDK):**
- `FIREBASE_SERVICE_ACCOUNT_KEY` - Service account JSON (encrypted with dotenvx)
- `ENABLE_AUTH` - Enable authentication (`true`/`false`)
- `REQUIRE_AUTH` - Require authentication for protected routes (`true`/`false`)

### Configuration by Environment

**Staging:**
- All services except Traefik are private
- All labs are protected by authentication
- Access to Traefik is restricted to IAM groups

**Production:**
- Services may or may not be private (configurable)
- All labs are protected by authentication
- Traefik may have public access or IAM restrictions

## Docker Compose Configuration

### Local Development with Authentication

**File:** `docker-compose.auth.yml`

```yaml
services:
  home-index:
    environment:
      - FIREBASE_API_KEY=${FIREBASE_API_KEY:-}
      - FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-ui-firebase-pcioasis-stg}
      - ENABLE_AUTH=${ENABLE_AUTH:-true}
      - REQUIRE_AUTH=${REQUIRE_AUTH:-true}
      - FIREBASE_SERVICE_ACCOUNT_KEY=${FIREBASE_SERVICE_ACCOUNT_KEY:-}
```

**Usage:**
```bash
# Run with authentication enabled
./deploy/docker-compose-auth.sh up -d --build
```

This script:
1. Decrypts `.env.stg` using dotenvx
2. Extracts Firebase configuration
3. Runs docker-compose with authentication enabled

## Troubleshooting

### Issue: "Email not verified" but user verified email

**Cause:** Token cache may be stale, or user needs to sign in again after verification.

**Fix:** User should sign out and sign in again to get a fresh token with updated verification status.

### Issue: Lab routes not protected

**Local (docker-compose):**
1. Use `./deploy/docker-compose-auth.sh up` so `auth-middlewares.yml` is mounted (ForwardAuth to home-index).
2. Lab routes in `docker-compose.yml` include `lab1-auth-check@file`.
3. `home-index-service` is running and `/api/auth/check` is accessible.

**Staging/Production (Cloud Run):**
1. The Traefik image does *not* include `local-auth-stubs.yml` (empty chains). It only includes `routes.yml` (strip-prefix, retry).
2. ForwardAuth middlewares (`lab1-auth-check`, etc.) are written at runtime by the entrypoint when `HOME_INDEX_URL` is set:
   - **Sidecar deploy** (traefik + provider containers): `deploy/traefik/entrypoint-sidecar.sh` writes `/shared/traefik/dynamic/auth-forward.yml`. Set `HOME_INDEX_URL` in `cloudrun-sidecar.yaml`; `deploy-sidecar.sh` and `deploy-sidecar-traefik-3.0.sh` substitute the home-index service URL when deploying.
   - **Plugin deploy** (single container): `deploy/traefik/entrypoint-plugin.sh` writes `/etc/traefik/dynamic/auth-forward.yml`; the deploy workflow or `deploy.sh` sets `HOME_INDEX_URL` on the service.
3. If lab routes are still public: (a) Verify `HOME_INDEX_URL` is set on the Traefik Cloud Run service (e.g. in the GCP Console or `gcloud run services describe traefik-stg --region=us-central1 --project=labs-stg --format='yaml(spec.template.spec.containers[0].env)'`). (b) If it is missing, run `./deploy/traefik/set-home-index-url.sh stg` to set it and create a new revision (no full redeploy needed). (c) Check Traefik logs for "auth-forward.yml written".

### Issue: Root path (/) returns 401 Unauthorized

**Cause:** The home page must stay public. Two safeguards are in place:

1. **Traefik:** When `HOME_INDEX_URL` is set, the sidecar entrypoint writes `auth-forward.yml` with a high-priority router `home-index-root-public` (rule `Path(\`/\`)`, priority 1000) so the exact path `/` is always served by home-index with no auth middleware, even if the provider’s home router had auth attached.
2. **home-index-service:** The Go auth middleware treats an empty path as `/` and has `/` in the public paths list, so the app never requires auth for the root.

**If you still see 401 on `/`:** (a) Confirm the Traefik image includes the updated entrypoint that adds `home-index-root-public` in `auth-forward.yml`. (b) Confirm home-index has the path normalization that sets `normalizedPath = "/"` when `r.URL.Path == ""`. (c) Check home-index logs for "Skipping auth for public path" vs "Auth middleware checking" to see whether the request is treated as public.

### Redeploy commands (rebuild and push after auth fixes)

Run from the repo root (`e-skimming-labs`).

**Home-index (staging)** — after changing `deploy/shared-components/home-index-service/` (e.g. auth middleware):

```bash
./deploy/shared-components/home-index-service/deploy-stg.sh
```

Optional image tag: `./deploy/shared-components/home-index-service/deploy-stg.sh my-tag`

**Home-index (staging or production)** — full home deploy (SEO + home-index):

```bash
./deploy/deploy-home.sh stg
# or
./deploy/deploy-home.sh prd
```

Optional: `./deploy/deploy-home.sh stg $(git rev-parse --short HEAD) --force-rebuild`

**Traefik sidecar (staging)** — after changing entrypoint or Traefik config (e.g. `auth-forward.yml`):

```bash
./deploy/traefik/deploy-sidecar.sh stg
```

**Traefik sidecar (production):**

```bash
./deploy/traefik/deploy-sidecar.sh prd
```

**Traefik v3.0 sidecar** (if you use the v3.0 image):

```bash
./deploy/traefik/deploy-sidecar-traefik-3.0.sh stg
# or
./deploy/traefik/deploy-sidecar-traefik-3.0.sh prd
```

**Only set HOME_INDEX_URL** (no image rebuild; new revision so lab auth works):

```bash
./deploy/traefik/set-home-index-url.sh stg
# or
./deploy/traefik/set-home-index-url.sh prd
```

### Issue: "Service account does not exist" error

**Cause:** Firebase Admin SDK runtime service account or Traefik service account doesn't exist.

**Fix:**
1. Apply Terraform to create service accounts
2. For Traefik: Apply `terraform-labs` first, then `terraform-home`
3. See `deploy/terraform-home/PRODUCTION_DEPLOYMENT.md` for details

### Issue: Cannot access Secret Manager secrets

**Cause:** Service account missing `roles/secretmanager.secretAccessor` permission.

**Fix:** Add the role in Terraform:
```terraform
resource "google_project_iam_member" "fbase_adm_sdk_runtime_roles" {
  for_each = toset([
    # ... other roles ...
    "roles/secretmanager.secretAccessor"  # Add this
  ])
  # ...
}
```

## Security Considerations

1. **Email Verification**: Required for all protected routes to prevent unauthorized access
2. **Token Validation**: All tokens are validated server-side using Firebase Admin SDK
3. **Service Account Keys**: Never stored in Terraform state, managed via scripts with encryption
4. **Secret Manager**: `DOTENVX_KEY_STG` is stored in Secret Manager, accessed via service account
5. **Traefik ForwardAuth**: Lab routes are protected at the reverse proxy level, before reaching containers

## Related Documentation

- `docs/FIREBASE_SERVICE_ACCOUNT_SETUP.md` - Setting up Firebase service account keys
- `deploy/terraform-home/PRODUCTION_DEPLOYMENT.md` - Production deployment and import process
- `deploy/secrets/SCRIPTS_SUMMARY.md` - Secrets management scripts
