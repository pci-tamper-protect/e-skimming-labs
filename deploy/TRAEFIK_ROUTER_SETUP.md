# Traefik as Single Entry Point Router - Implementation Guide

## Overview

Traefik is configured as the single entry point for `labs.stg.pcioasis.com`. All client traffic goes through Traefik, which routes to backend services. Backend services are completely private (no public access, no IAM needed for users).

## Architecture

```
Users → labs.stg.pcioasis.com (Traefik with IAM groups) → Backend Services (private, service account auth)
```

### Benefits

1. **Single Authentication Point**: Users authenticate once to Traefik (via IAM groups)
2. **Private Backends**: Backend services are completely private (no public access)
3. **No Proxy Needed**: Users don't need to proxy individual services
4. **Simpler IAM**: Only Traefik needs IAM group bindings

## Implementation Status

### ✅ Step 1: Traefik IAM Group Bindings

**File**: `deploy/terraform-labs/traefik.tf` (lines 189-200)

Traefik has IAM group bindings for staging:
- `group:2025-interns@pcioasis.com`
- `group:core-eng@pcioasis.com`

Only these groups can access Traefik in staging.

### ✅ Step 3: Traefik Service Account Permissions

**File**: `deploy/terraform-labs/traefik.tf` (lines 12-17)

Traefik's service account has project-level `roles/run.invoker` on `labs-stg` project, which grants access to:
- `labs-analytics-stg`
- `lab-01-basic-magecart-stg`
- `lab-02-dom-skimming-stg`
- `lab-03-extension-hijacking-stg`
- All lab C2 servers

**File**: `deploy/terraform-home/iap.tf` (new bindings)

Traefik's service account has service-specific `roles/run.invoker` on home services:
- `home-index-stg` (in `labs-home-stg` project)
- `home-seo-stg` (in `labs-home-stg` project)

### ✅ Step 4: Domain Mapping

**File**: `deploy/terraform-labs/traefik.tf` (lines 202-226)

Domain mapping is configured:
- **Staging**: `labs.stg.pcioasis.com` → `traefik-stg`
- **Production**: `labs.pcioasis.com` → `traefik-prd`

## Deployment Steps

### 1. Apply Terraform Changes

```bash
# Apply labs project Terraform (Traefik service, IAM, domain mapping)
cd deploy/terraform-labs
terraform init -backend-config=backend-stg.conf
terraform plan -var="environment=stg" -var="project_id=labs-stg"
terraform apply

# Apply home project Terraform (Traefik service account access)
cd ../terraform-home
terraform init -backend-config=backend-stg.conf
terraform plan -var="environment=stg" -var="project_id=labs-home-stg"
terraform apply
```

### 2. Deploy Traefik Service

```bash
# Build and push Traefik image
cd deploy/traefik
./build-and-push.sh stg

# Then deploy via gcloud
gcloud run deploy traefik-stg \
  --image=us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik:latest \
  --region=us-central1 \
  --project=labs-stg \
  --service-account=traefik-stg@labs-stg.iam.gserviceaccount.com \
  --port=8080 \
  --labels="environment=stg,component=traefik,project=e-skimming-labs,service-type=router"

# Or use Terraform (recommended)
cd ../terraform-labs
terraform apply -var="environment=stg"
```

### 3. Verify Domain Mapping

```bash
# Check domain mapping
gcloud run domain-mappings describe labs.stg.pcioasis.com \
  --region=us-central1 \
  --project=labs-stg

# Should show route_name: traefik-stg
```

### 4. Test Access

```bash
# Test Traefik access (should require authentication)
curl -I https://labs.stg.pcioasis.com/

# With authentication (using gcloud proxy)
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8081

# Then access http://localhost:8081/
```

## Backend Service Configuration

### Making Backend Services Private

Backend services should be deployed with `--no-allow-unauthenticated` and **without** IAM group bindings. Only Traefik's service account needs access.

**Current State**: Some backend services may still have IAM group bindings. These can be removed once Traefik is the single entry point.

**To remove group bindings from backend services** (after Traefik is deployed):

```bash
# Remove group bindings from home-index-stg (users access via Traefik now)
gcloud run services remove-iam-policy-binding home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --member="group:2025-interns@pcioasis.com" \
  --role="roles/run.invoker"

gcloud run services remove-iam-policy-binding home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --member="group:core-eng@pcioasis.com" \
  --role="roles/run.invoker"

# Repeat for other backend services
```

**Note**: Keep Traefik's service account bindings - those are required for Traefik to call the backends.

## Service Account Authentication

Traefik uses its service account (`traefik-stg@labs-stg.iam.gserviceaccount.com`) to authenticate to backend services. When Traefik makes requests to backend services, it:

1. Uses Application Default Credentials (ADC) from its service account
2. Automatically includes an identity token in the `Authorization: Bearer` header
3. Backend services verify the token and allow the request

This happens automatically - no additional configuration needed in Traefik.

## Troubleshooting

### Traefik can't reach backend services

1. **Check service account permissions**:
   ```bash
   # Verify Traefik service account has invoker role
   gcloud projects get-iam-policy labs-stg \
     --flatten="bindings[].members" \
     --filter="bindings.members:traefik-stg@labs-stg.iam.gserviceaccount.com"
   ```

2. **Check home service permissions**:
   ```bash
   # Verify Traefik can invoke home-index-stg
   gcloud run services get-iam-policy home-index-stg \
     --region=us-central1 \
     --project=labs-home-stg | grep traefik
   ```

3. **Check backend service is private**:
   ```bash
   # Should NOT have allUsers binding
   gcloud run services get-iam-policy home-index-stg \
     --region=us-central1 \
     --project=labs-home-stg | grep allUsers
   ```

### Users can't access Traefik

1. **Check group membership**:
   ```bash
   gcloud identity groups memberships check-transitive-membership \
     --group-email="2025-interns@pcioasis.com" \
     --member-email="user@example.com"
   ```

2. **Check Traefik IAM bindings**:
   ```bash
   gcloud run services get-iam-policy traefik-stg \
     --region=us-central1 \
     --project=labs-stg
   ```

### Domain not pointing to Traefik

1. **Check domain mapping**:
   ```bash
   gcloud run domain-mappings describe labs.stg.pcioasis.com \
     --region=us-central1 \
     --project=labs-stg
   ```

2. **Update domain mapping if needed**:
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

## Migration Checklist

- [x] Traefik IAM group bindings configured
- [x] Traefik service account has invoker permissions on all backend services
- [x] Domain mapping configured to point to Traefik
- [ ] Traefik service deployed
- [ ] Domain mapping applied/verified
- [ ] Backend services made private (remove group bindings)
- [ ] Test access through Traefik
- [ ] Update documentation

## Next Steps

1. Apply Terraform changes to create IAM bindings
2. Deploy Traefik service
3. Verify domain mapping points to Traefik
4. Test access through Traefik
5. Remove IAM group bindings from backend services (make them private)
6. Update GitHub Actions workflow to ensure backend services are deployed as private
