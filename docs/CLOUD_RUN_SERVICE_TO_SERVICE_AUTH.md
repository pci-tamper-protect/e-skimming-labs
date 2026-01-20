# Cloud Run Service-to-Service Authentication

## Overview

When one Cloud Run service needs to call another Cloud Run service, it requires specific IAM permissions to:
1. Generate identity tokens (for the calling service)
2. Invoke the target service (for the target service)

## Required Permissions

### 1. Token Generation (Calling Service)

The calling service's service account needs permission to generate identity tokens:

**Role**: `roles/iam.serviceAccountTokenCreator`

**Scope**: On the calling service's own service account (self-impersonation)

**Why**: Cloud Run services automatically generate identity tokens using their service account. The service account needs permission to create tokens for itself.

**Example** (Traefik generating tokens):
```bash
# Grant Traefik SA permission to generate tokens for itself
gcloud iam service-accounts add-iam-policy-binding \
  traefik-stg@labs-stg.iam.gserviceaccount.com \
  --member="serviceAccount:traefik-stg@labs-stg.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project=labs-stg
```

**Note**: This is usually granted automatically when a service account is created, but can be missing if the service account was created manually or permissions were removed.

### 2. Service Invocation (Target Service)

The target service must grant the calling service permission to invoke it:

**Role**: `roles/run.invoker`

**Scope**: On the target Cloud Run service

**Why**: Cloud Run services are private by default. The target service must explicitly grant access to the calling service's service account.

**Example** (Lab service granting Traefik access):
```bash
# Grant Traefik SA permission to invoke lab-01-basic-magecart-stg
gcloud run services add-iam-policy-binding \
  lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg \
  --member="serviceAccount:traefik-stg@labs-stg.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

## How It Works

1. **Service A (Caller)** wants to call **Service B (Target)**
2. **Service A** uses its service account to generate an identity token:
   - **Token audience: MUST exactly match Service B's URL** (e.g., `https://service-b-xxx.run.app`)
   - Uses Application Default Credentials (ADC) from Service A's service account
   - **CRITICAL**: The audience URL must match the URL used in the HTTP request
3. **Service A** makes HTTP request to **Service B** with token:
   - URL: Must match the audience used in token generation
   - Header: `Authorization: Bearer <identity-token>`
4. **Service B** validates the token:
   - Checks the token is valid and not expired
   - Checks the token's audience matches the request URL
   - Checks the caller's service account has `roles/run.invoker` on Service B
5. If valid, **Service B** processes the request

## Audience Field Requirements

**The `audiences` field is REQUIRED and must exactly match the service URL.**

### Cloud Run URL Formats

Cloud Run services have multiple URL formats:

1. **Random-suffix URL** (volatile): `https://service-xxxxxx-uc.a.run.app`
   - Changes when service is redeployed
   - Not recommended for production use

2. **Numeric stable URL** (preferred): `https://service-207478017187.us-central1.run.app`
   - Stable across redeployments
   - Recommended for production use

3. **Custom domain**: `https://custom-domain.com`
   - If domain mapping is configured

### Critical Rule: Audience Must Match Request URL

**The audience used to generate the token MUST exactly match the URL used in the HTTP request.**

```bash
# ✅ CORRECT: Same URL for both token and request
TOKEN=$(gcloud auth print-identity-token --audiences="https://service-207478017187.us-central1.run.app")
curl -H "Authorization: Bearer $TOKEN" https://service-207478017187.us-central1.run.app/

# ❌ WRONG: Different URLs
TOKEN=$(gcloud auth print-identity-token --audiences="https://service-xxxxxx-uc.a.run.app")
curl -H "Authorization: Bearer $TOKEN" https://service-207478017187.us-central1.run.app/
# This will fail - token audience doesn't match request URL
```

### Getting the Correct Service URL

Always use the same URL format for both token generation and requests:

```bash
# Get the service URL (returns the random-suffix URL by default)
SERVICE_URL=$(gcloud run services describe service-name \
  --region=us-central1 \
  --project=project-id \
  --format="value(status.url)")

# Use this SAME URL for both token generation and requests
TOKEN=$(gcloud auth print-identity-token --audiences="$SERVICE_URL")
curl -H "Authorization: Bearer $TOKEN" "$SERVICE_URL/"
```

**Note**: If you're using a custom domain or numeric stable URL, use that consistently for both token generation and requests.

## Common Issues

### Issue 1: "Your client does not have permission"

**Symptom**: 401 Unauthorized with message "Your client does not have permission"

**Cause**: The calling service's service account doesn't have `roles/run.invoker` on the target service

**Fix**:
```bash
gcloud run services add-iam-policy-binding <target-service> \
  --region=<region> \
  --project=<project> \
  --member="serviceAccount:<caller-service-account>" \
  --role="roles/run.invoker"
```

### Issue 2: Token generation fails

**Symptom**: Cannot generate identity token, or token generation hangs

**Cause**: The calling service's service account doesn't have `roles/iam.serviceAccountTokenCreator` on itself

**Fix**:
```bash
gcloud iam service-accounts add-iam-policy-binding <caller-service-account> \
  --member="serviceAccount:<caller-service-account>" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project=<project>
```

### Issue 3: 502 Bad Gateway

**Symptom**: 502 Bad Gateway when calling service

**Cause**: Usually means the request never reached the target service, or the target service is down. Can also indicate token generation failed silently.

**Debug**:
1. Check if target service is running
2. Check if token generation is working
3. Check Traefik logs for token generation errors

## Project-Level vs Service-Level Permissions

### Project-Level (Broad Access)

Granting `roles/run.invoker` at the project level allows the service account to invoke ALL services in that project:

```bash
gcloud projects add-iam-policy-binding <project-id> \
  --member="serviceAccount:<service-account>" \
  --role="roles/run.invoker"
```

**Use case**: When a service (like Traefik) needs to call multiple services in the same project.

**Example**: Traefik needs to call all lab services in `labs-stg` project.

### Service-Level (Specific Access)

Granting `roles/run.invoker` at the service level allows the service account to invoke ONLY that specific service:

```bash
gcloud run services add-iam-policy-binding <service-name> \
  --region=<region> \
  --project=<project> \
  --member="serviceAccount:<service-account>" \
  --role="roles/run.invoker"
```

**Use case**: When a service needs to call a specific service in a different project.

**Example**: Traefik (in `labs-stg`) needs to call `home-index-stg` (in `labs-home-stg`).

## Current Setup in This Project

### Traefik → Labs Services (Same Project)

**Location**: `deploy/terraform-labs/traefik.tf` (lines 12-17)

```hcl
resource "google_project_iam_member" "traefik_invoker" {
  project = local.labs_project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.traefik.email}"
}
```

**Effect**: Traefik SA can invoke ALL services in `labs-stg` project (labs, analytics, etc.)

### Traefik → Home Services (Different Project)

**Location**: `deploy/terraform-home/iap.tf`

```hcl
resource "google_cloud_run_v2_service_iam_member" "traefik_home_index" {
  location = var.region
  project  = local.home_project_id
  name     = "home-index-${var.environment}"
  role     = "roles/run.invoker"
  member   = "serviceAccount:traefik-${var.environment}@${local.labs_project_id}.iam.gserviceaccount.com"
}
```

**Effect**: Traefik SA can invoke specific home services in `labs-home-stg` project

## Testing Service-to-Service Auth

### Test Token Generation

**CRITICAL**: Always use the same URL for both token generation and the request.

```bash
# Get the service URL first
SERVICE_URL=$(gcloud run services describe lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="value(status.url)")

# Use the SAME URL for token generation
gcloud auth print-identity-token \
  --impersonate-service-account=traefik-stg@labs-stg.iam.gserviceaccount.com \
  --audiences="${SERVICE_URL}"
```

### Test Service Invocation

**CRITICAL**: Use the exact same URL for both token and request.

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="value(status.url)")

# Generate token with the service URL as audience
TOKEN=$(gcloud auth print-identity-token \
  --impersonate-service-account=traefik-stg@labs-stg.iam.gserviceaccount.com \
  --audiences="${SERVICE_URL}")

# Call service with token - MUST use the SAME URL
curl -H "Authorization: Bearer $TOKEN" "${SERVICE_URL}/"
```

### Common URL Mismatch Issues

**Problem**: Token generated with one URL format, but request uses different URL format.

**Example of mismatch**:
```bash
# ❌ WRONG: Different URLs
TOKEN=$(gcloud auth print-identity-token \
  --audiences="https://lab-01-basic-magecart-stg-xxxxxx-uc.a.run.app")  # Random suffix

curl -H "Authorization: Bearer $TOKEN" \
  https://lab-01-basic-magecart-stg-207478017187.us-central1.run.app/  # Numeric stable
# This will fail - audience mismatch!
```

**Solution**: Always use the same URL format:
```bash
# ✅ CORRECT: Same URL for both
SERVICE_URL="https://lab-01-basic-magecart-stg-207478017187.us-central1.run.app"
TOKEN=$(gcloud auth print-identity-token --audiences="${SERVICE_URL}")
curl -H "Authorization: Bearer $TOKEN" "${SERVICE_URL}/"
```

**Note**: `gcloud run services describe --format="value(status.url)"` returns the random-suffix URL. If you're using a numeric stable URL or custom domain, use that consistently for both token generation and requests.

## Summary

For Service A to call Service B:

1. **Service A's SA** needs `roles/iam.serviceAccountTokenCreator` on itself (usually automatic)
2. **Service B** must grant `roles/run.invoker` to Service A's SA (explicit grant required)
3. **Token audience MUST exactly match the request URL** - this is critical!

The identity token is automatically generated by Cloud Run using Application Default Credentials (ADC), and automatically included in requests when using the Cloud Run client libraries or when manually adding the `Authorization: Bearer <token>` header.

### Key Takeaway: Audience Matching

**The `audiences` field is REQUIRED and must exactly match the service URL used in the HTTP request.**

- ✅ Same URL for token generation and request = Works
- ❌ Different URLs = Token validation fails (401 Unauthorized)

Always use the same URL format (random-suffix, numeric stable, or custom domain) for both token generation and the actual HTTP request.
