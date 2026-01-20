# Cloud Run Admin API Permissions Required

## Problem

To use the Cloud Run Admin API REST endpoints (instead of `gcloud` CLI), the Traefik service account needs additional permissions to **read** service metadata.

## Required Permissions

### For Listing Services
- **Permission**: `run.services.list`
- **Role**: `roles/run.viewer` (includes this permission)

### For Getting Service Details
- **Permission**: `run.services.get`
- **Role**: `roles/run.viewer` (includes this permission)

## Current Traefik Service Account Permissions

**Location**: `deploy/terraform-labs/traefik.tf`

Currently has:
- ✅ `roles/run.invoker` (project-level) - Can invoke services
- ✅ `roles/artifactregistry.reader` - Can pull images
- ❌ **MISSING**: `roles/run.viewer` - Cannot read service metadata

## Solution

Add `roles/run.viewer` to the Traefik service account at the **project level** so it can:
1. List all Cloud Run services in the project
2. Get service details (labels, URLs, etc.) via REST API

### Option 1: Add via Terraform (Recommended)

**File**: `deploy/terraform-labs/traefik.tf`

Add after line 24:

```hcl
# Grant Traefik permission to read Cloud Run service metadata (for label-based route generation)
resource "google_project_iam_member" "traefik_viewer" {
  project = local.labs_project_id
  role    = "roles/run.viewer"
  member  = "serviceAccount:${google_service_account.traefik.email}"
}
```

**Also add for home project** (if Traefik needs to read home services):

**File**: `deploy/terraform-home/iap.tf` (or create new resource)

```hcl
# Grant Traefik permission to read home project Cloud Run services
resource "google_project_iam_member" "traefik_home_viewer" {
  project = local.home_project_id
  role    = "roles/run.viewer"
  member  = "serviceAccount:traefik-${var.environment}@${local.labs_project_id}.iam.gserviceaccount.com"
}
```

### Option 2: Add via gcloud (Quick Fix)

```bash
# For labs project
gcloud projects add-iam-policy-binding labs-stg \
  --member="serviceAccount:traefik-stg@labs-stg.iam.gserviceaccount.com" \
  --role="roles/run.viewer"

# For home project (if needed)
gcloud projects add-iam-policy-binding labs-home-stg \
  --member="serviceAccount:traefik-stg@labs-stg.iam.gserviceaccount.com" \
  --role="roles/run.viewer"
```

## Why `roles/run.viewer`?

- **Read-only access** - Can list and get service details, but cannot modify services
- **Principle of least privilege** - Only grants what's needed for route generation
- **Includes both permissions** - `run.services.list` and `run.services.get` are included

## Alternative: Custom Role (More Restrictive)

If you want even more restrictive permissions, create a custom role with only:
- `run.services.list`
- `run.services.get`

But `roles/run.viewer` is the standard read-only role and is appropriate for this use case.

## Verification

After granting permissions, verify:

```bash
# Check if Traefik SA has run.viewer role
gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:traefik-stg@labs-stg.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

Should show:
- `roles/run.invoker`
- `roles/run.viewer` ← **NEW**
- `roles/artifactregistry.reader`




