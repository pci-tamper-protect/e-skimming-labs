# IAM Setup and Service Accounts

This document describes:
1. All service accounts in labs-stg and labs-home-stg projects
2. IAM-based access control for staging environments
3. Local development authentication options

---

## Service Accounts

### labs-stg Project

| Service Account | Purpose | Key Roles |
|-----------------|---------|-----------|
| `traefik-stg@labs-stg.iam.gserviceaccount.com` | Traefik reverse proxy gateway (Cloud Run) | `roles/run.viewer`, `roles/run.invoker`, `roles/artifactregistry.reader` |
| `traefik-provider-token-sa@labs-stg.iam.gserviceaccount.com` | **Local dev & CI/CD testing** | `roles/run.viewer`, `roles/run.invoker`, `roles/iam.serviceAccountTokenCreator` |
| `labs-runtime-sa@labs-stg.iam.gserviceaccount.com` | Runtime SA for lab services | `roles/run.invoker`, `roles/run.viewer`, `roles/datastore.user`, `roles/artifactregistry.reader` |
| `labs-analytics-sa@labs-stg.iam.gserviceaccount.com` | Analytics service runtime | `roles/datastore.user`, `roles/logging.logWriter`, `roles/monitoring.metricWriter` |
| `labs-seo-sa@labs-stg.iam.gserviceaccount.com` | SEO service runtime | `roles/datastore.user` |
| `labs-deploy-sa@labs-stg.iam.gserviceaccount.com` | CI/CD deployment | `roles/run.admin`, `roles/artifactregistry.writer`, `roles/iam.serviceAccountUser` |
| `1078730674198-compute@developer.gserviceaccount.com` | Default compute SA (avoid using) | Various default roles |

### labs-home-stg Project

| Service Account | Purpose | Key Roles |
|-----------------|---------|-----------|
| `home-runtime-sa@labs-home-stg.iam.gserviceaccount.com` | Runtime SA for home services | `roles/run.invoker`, `roles/run.viewer` |
| `home-seo-sa@labs-home-stg.iam.gserviceaccount.com` | SEO service runtime | `roles/datastore.user` |
| `home-deploy-sa@labs-home-stg.iam.gserviceaccount.com` | CI/CD deployment | `roles/run.admin`, `roles/artifactregistry.writer` |
| `fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com` | Firebase Admin SDK for auth | Firebase Admin SDK roles |
| `327539540168-compute@developer.gserviceaccount.com` | Default compute SA (avoid using) | Various default roles |

---

## Local Development Authentication

### Option 1: ADC with Service Account Impersonation (Recommended)

User credentials (ADC) cannot directly generate identity tokens. Use impersonation:

```bash
# 1. Login with your user account
gcloud auth application-default login

# 2. Set impersonation in docker-compose.sidecar-local.yml
# The provider will impersonate traefik-stg to generate identity tokens
IMPERSONATE_SERVICE_ACCOUNT=traefik-stg@labs-stg.iam.gserviceaccount.com
```

**Required permissions on your user account:**
- `roles/iam.serviceAccountTokenCreator` on `traefik-stg@labs-stg.iam.gserviceaccount.com`

### Option 2: Service Account Key (For CI/CD or long-running local dev)

Use the dedicated `traefik-provider-token-sa` service account with minimal permissions.

```bash
# Setup SA, grant permissions, create key, upload to GitHub (idempotent)
./deploy/traefik/iam.sh stg   # for staging
./deploy/traefik/iam.sh prd   # for production
```

The `iam.sh` script:
1. Creates `traefik-provider-token-sa@labs-{stg|prd}.iam.gserviceaccount.com`
2. Grants `roles/run.viewer` and `roles/run.invoker` on both labs and home projects
3. Grants `roles/iam.serviceAccountTokenCreator` on itself
4. Creates key and uploads to GitHub secret `TRAEFIK_PROVIDER_SA_KEY_{STG|PRD}`

**Why one combined SA instead of separate provider/gateway SAs?**

In theory, least privilege would suggest two separate SAs:
- **Provider SA**: `roles/run.viewer` only (query services for route discovery)
- **Gateway SA**: `roles/run.invoker` + `roles/iam.serviceAccountTokenCreator` (invoke services)

However, we use a single combined SA because:
1. **Cloud Run sidecar architecture**: In production, Traefik and the provider run as sidecars in the same Cloud Run service, sharing the same service account (`traefik-stg@`)
2. **Simpler local simulation**: For local dev and CI, using one SA mirrors the production setup
3. **Practical security**: The provider needs to generate identity tokens to test routes, which requires the same permissions as the gateway

**For local development, create a local key:**
```bash
# Create a key for local use
gcloud iam service-accounts keys create ~/traefik-provider-token-sa-key.json \
  --iam-account=traefik-provider-token-sa@labs-stg.iam.gserviceaccount.com \
  --project=labs-stg

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/traefik-provider-token-sa-key.json
```

**Or mount in docker-compose:**
```yaml
volumes:
  - ~/traefik-provider-token-sa-key.json:/etc/secrets/sa-key.json:ro
environment:
  - GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/sa-key.json
```

### Minimum Permissions for Local Provider

The `traefik-cloudrun-provider` needs these permissions:

| Permission | Role | Purpose |
|------------|------|---------|
| `run.services.list` | `roles/run.viewer` | Discover services with traefik labels |
| `run.services.get` | `roles/run.viewer` | Read service metadata and labels |
| `run.routes.invoke` | `roles/run.invoker` | Generate identity tokens for backend services |

**Cross-project access:** The SA also needs `roles/run.viewer` in `labs-home-stg` to discover home services.

---

## IAM-based Access Control for Staging

This section describes how IAM-based access control is configured to restrict access to staging services to only developers in the `2025-interns` and `core-eng` groups.

**Note:** This uses IAM bindings (not Load Balancer with IAP) to avoid costs. Load Balancers have a base cost even with no traffic.

## Overview

For the staging (`stg`) environment, access to Cloud Run services is restricted using IAM-based access control. Only members of the following Google Groups can access staging services:

- `2025-interns@pcioasis.com`
- `core-eng@pcioasis.com`

Production (`prd`) services remain publicly accessible.

## Architecture

### IAM-Based Access Control (Current Implementation)

This approach uses Google Cloud IAM to restrict access **without** a Load Balancer:

1. **Staging services**: Deployed with `--no-allow-unauthenticated`
2. **IAM bindings**: Grant `roles/run.invoker` to specific groups (`2025-interns@pcioasis.com`, `core-eng@pcioasis.com`)
3. **Production services**: Deployed with `--allow-unauthenticated` (public access)

**Why not Load Balancer with IAP?**
- Load Balancers have a base cost (~$18/month) even with no traffic
- IAM-based access control is free and sufficient for our needs
- Can upgrade to Load Balancer + IAP later if needed for audit logs, session management, etc.

### Services Protected

The following services are restricted in staging:

#### Labs Project (`labs-stg`)
- `labs-analytics-stg` - Analytics service
- `lab-01-basic-magecart-stg` - Lab 1
- `lab-02-dom-skimming-stg` - Lab 2
- `lab-03-extension-hijacking-stg` - Lab 3
- (Any other lab services)

#### Home Project (`labs-home-stg`)
- `home-seo-stg` - SEO service
- `home-index-stg` - Index/landing page service

## Terraform Configuration

### Files Created

1. **`terraform-labs/iap.tf`** - IAM bindings for labs project services (analytics)
2. **`terraform-home/iap.tf`** - IAM bindings for home project services (SEO, Index)

### Key Resources

```hcl
# Group-based IAM bindings (staging only)
# No IAP API needed - using IAM directly
resource "google_cloud_run_v2_service_iam_member" "stg_group_access" {
  for_each = var.deploy_services && var.environment == "stg" ? toset([
    "group:2025-interns@pcioasis.com",
    "group:core-eng@pcioasis.com"
  ]) : toset([])
  
  location = google_cloud_run_v2_service.analytics_service[0].location
  project  = google_cloud_run_v2_service.analytics_service[0].project
  name     = google_cloud_run_v2_service.analytics_service[0].name
  role     = "roles/run.invoker"
  member   = each.value
}
```

## GitHub Actions Workflow Changes

The `deploy_labs.yml` workflow has been updated to:

1. **Staging services**: Deploy with `--no-allow-unauthenticated` and grant IAM access to groups
2. **Production services**: Deploy with `--allow-unauthenticated` (public access)
3. **Both environments**: Services are configured appropriately based on `environment` variable

### Services Updated in Workflow

- **Home Project**: `home-seo-stg`, `home-index-stg`
- **Labs Project**: `labs-analytics-stg`, `labs-index-stg`, `lab-*-stg` (individual labs)

## Deployment Steps

### 1. Authenticate with Google Cloud

```bash
gcloud auth application-default login
```

### 2. Apply Terraform Changes

```bash
cd deploy/terraform-labs
terraform init -backend-config=backend-stg.conf
terraform plan -var="environment=stg" -var="project_id=labs-stg"
terraform apply

cd ../terraform-home
terraform init -backend-config=backend-stg.conf
terraform plan -var="environment=stg" -var="project_id=labs-home-stg"
terraform apply
```

### 2. Verify Group Access

After deployment, verify that groups have access:

```bash
# Check IAM policy for a staging service
gcloud run services get-iam-policy lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg
```

You should see bindings for:
- `group:2025-interns@pcioasis.com` with role `roles/run.invoker`
- `group:core-eng@pcioasis.com` with role `roles/run.invoker`

### 3. Test Access

**Important**: Cloud Run IAM authentication works differently than IAP. It does **not** automatically redirect to Google sign-in in the browser. You need to access the service with authentication.

#### Method 1: Use gcloud to proxy (Recommended)

```bash
# This opens a local proxy that handles authentication
gcloud run services proxy home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --port=8099
```

Then open `http://localhost:8099` in your browser. The proxy handles authentication automatically.

#### Method 2: Use curl with identity token

```bash
# Get an identity token
TOKEN=$(gcloud auth print-identity-token)

# Access the service
curl -H "Authorization: Bearer $TOKEN" \
  https://home-index-stg-327539540168.us-central1.run.app/
```

#### Method 3: Access via authenticated browser session

If you're already logged into Google Cloud Console in your browser, you can try accessing the URL directly. However, this doesn't always work reliably.

**Note**: Unlike IAP (Identity-Aware Proxy), Cloud Run's built-in IAM does **not** automatically redirect unauthenticated users to a sign-in page. If you access the URL directly without authentication, you'll get a 403 Forbidden error without being prompted to sign in.

#### Expected Behavior

1. **As a group member with authentication**: Should be able to access staging URLs
2. **As a non-member**: Should receive 403 Forbidden
3. **Without authentication**: Will receive 403 Forbidden (no redirect to sign-in)

## Adding New Groups

To add additional groups to staging access:

1. Update `terraform-labs/iap.tf` and `terraform-home/iap.tf`:
   ```hcl
   for_each = var.environment == "stg" ? toset([
     "group:2025-interns@pcioasis.com",
     "group:core-eng@pcioasis.com",
     "group:new-group@pcioasis.com"  # Add here
   ]) : toset([])
   ```

2. Update `deploy_labs.yml` workflow to grant access to new group

3. Apply Terraform changes

## Troubleshooting

### Users can't access staging services

1. **Verify group membership**:
   ```bash
   # Check if user is in the group
   gcloud identity groups memberships check-transitive-membership \
     --group-email="2025-interns@pcioasis.com" \
     --member-email="user@example.com"
   ```

2. **Check IAM bindings**:
   ```bash
   gcloud run services get-iam-policy SERVICE_NAME \
     --region=us-central1 \
     --project=labs-stg
   ```

3. **Verify service is not public**:
   ```bash
   # Should NOT have allUsers binding
   gcloud run services get-iam-policy SERVICE_NAME \
     --region=us-central1 \
     --project=labs-stg | grep allUsers
   ```

### Service shows as "public" in console

If a staging service shows as publicly accessible:

1. Remove `allUsers` binding:
   ```bash
   gcloud run services remove-iam-policy-binding SERVICE_NAME \
     --region=us-central1 \
     --member="allUsers" \
     --role="roles/run.invoker"
   ```

2. Re-apply Terraform to ensure correct IAM bindings

## Cost Considerations

### Why Not Use Load Balancer with IAP?

Google Cloud Load Balancers have a **base cost of ~$18/month** even with zero traffic:
- Forwarding rules: ~$18/month per rule
- Additional costs for data processing

For low-traffic staging environments, IAM-based access control is:
- **Free** (no additional cost)
- **Sufficient** for basic access control
- **Simple** to configure and maintain

### When to Consider Load Balancer + IAP

Consider upgrading if you need:
- Centralized audit logging
- Session management
- More granular access policies
- Advanced IAP features

See: https://cloud.google.com/iap/docs/load-balancer-howto

## References

- [Cloud Run IAM](https://cloud.google.com/run/docs/securing/managing-access)
- [Identity Aware Proxy](https://cloud.google.com/iap/docs/overview)
- [Google Groups IAM](https://cloud.google.com/iam/docs/overview#groups)

