# Production Deployment Guide

This guide covers deploying Terraform infrastructure to production, including importing existing resources and handling common errors.

## ⚠️ Important: Terraform Scope

**Terraform does NOT manage Cloud Run services or service account keys.**

- ✅ **Managed by Terraform**: Service accounts, IAM bindings, storage, VPC connectors, Artifact Registry, Firestore
- ❌ **NOT managed by Terraform**: Cloud Run services (managed by GitHub Actions), service account keys (managed by scripts)

See [TERRAFORM_SCOPE.md](./TERRAFORM_SCOPE.md) for full architectural details.

## Prerequisites

1. **Terraform state bucket exists**: The production state bucket must be created before initializing Terraform
2. **Traefik service account exists**: The Traefik service account must be created in the `terraform-labs` project first
3. **gcloud authenticated**: You must be authenticated with appropriate permissions

## Initial Setup

### Step 1: Create Terraform State Bucket

```bash
gcloud storage buckets create gs://e-skimming-labs-terraform-state-prd \
  --project=labs-home-prd \
  --location=us-central1 \
  --uniform-bucket-level-access
```

### Step 2: Initialize Terraform

```bash
cd deploy/terraform-home
terraform init -reconfigure -backend-config=backend-prd.conf
```

The `-reconfigure` flag tells Terraform to use the new backend configuration without trying to migrate state from staging.

### Step 3: Import Existing Resources

Production resources already exist and need to be imported into Terraform state. Use the automated import script:

```bash
./import-prd.sh
```

This script imports:
- Service accounts (home-runtime-sa, home-deploy-sa, home-seo-sa, fbase-adm-sdk-runtime)
- Artifact Registry repository
- Firestore database
- Storage bucket
- VPC connector (if exists)
- Cloud Run services (home-seo-prd, home-index-prd)

**Manual Import (if script fails):**

If the script fails for specific resources, import them manually:

```bash
# Service accounts
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_service_account.home_runtime \
  projects/labs-home-prd/serviceAccounts/home-runtime-sa@labs-home-prd.iam.gserviceaccount.com

terraform import -var="environment=prd" -var="deploy_services=true" \
  google_service_account.home_deploy \
  projects/labs-home-prd/serviceAccounts/home-deploy-sa@labs-home-prd.iam.gserviceaccount.com

terraform import -var="environment=prd" -var="deploy_services=true" \
  google_service_account.home_seo \
  projects/labs-home-prd/serviceAccounts/home-seo-sa@labs-home-prd.iam.gserviceaccount.com

terraform import -var="environment=prd" -var="deploy_services=true" \
  google_service_account.fbase_adm_sdk_runtime \
  projects/labs-home-prd/serviceAccounts/fbase-adm-sdk-runtime@labs-home-prd.iam.gserviceaccount.com

# Artifact Registry
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_artifact_registry_repository.home_repo \
  us-central1-docker.pkg.dev/labs-home-prd/e-skimming-labs-home

# Firestore database
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_firestore_database.home_db \
  projects/labs-home-prd/databases/(default)

# Storage bucket
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_storage_bucket.home_assets \
  labs-home-prd-home-assets

# Cloud Run services - NOT imported (managed by GitHub Actions, not Terraform)
# See TERRAFORM_SCOPE.md for architectural details
# IAM bindings use data sources to reference services (see iap.tf)
#
# If Cloud Run services are already in Terraform state, remove them:
#   ./remove-cloud-run-from-state.sh prd
```

## Deployment

### Step 4: Plan Changes

```bash
terraform plan \
  -var="environment=prd" \
  -var="deploy_services=true"
```

Review the plan to ensure:
- Service accounts are imported (not being created)
- IAM bindings will be created/updated
- Cloud Run services are in state (but won't be modified due to `lifecycle { ignore_changes = all }`)

### Step 5: Apply Changes

```bash
terraform apply \
  -var="environment=prd" \
  -var="deploy_services=true"
```

**Note:** Always use `deploy_services=true` for production. This ensures:
- Service accounts and IAM bindings are managed
- Cloud Run services stay in state (but aren't modified - GitHub Actions manages them)
- Outputs work correctly

## Common Errors and Fixes

### Error: "Service account already exists"

**Error:**
```
Error: Error 409: Service account home-seo-sa already exists within project
```

**Fix:** Import the existing service account into Terraform state:
```bash
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_service_account.home_seo \
  projects/labs-home-prd/serviceAccounts/home-seo-sa@labs-home-prd.iam.gserviceaccount.com
```

### Error: "Bucket already exists"

**Error:**
```
Error: Error 409: Your previous request to create the named bucket succeeded and you already own it.
```

**Fix:** Import the existing bucket:
```bash
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_storage_bucket.home_assets \
  labs-home-prd-home-assets
```

### Error: "Database already exists"

**Error:**
```
Error: Error 409: Database already exists. Please use another database_id
```

**Fix:** Import the existing Firestore database:
```bash
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_firestore_database.home_db \
  projects/labs-home-prd/databases/(default)
```

### Error: "Traefik service account does not exist"

**Error:**
```
Error: Service account traefik-prd@labs-prd.iam.gserviceaccount.com does not exist.
```

**Fix:** The Traefik service account is created in the `terraform-labs` project. You have two options:

**Option 1: Apply terraform-labs first (Recommended)**
```bash
# Apply terraform-labs to create Traefik service account
cd ../terraform-labs
terraform init -reconfigure -backend-config=backend-prd.conf
terraform apply -var="environment=prd"

# Then re-run terraform-home
cd ../terraform-home
terraform apply -var="environment=prd" -var="deploy_services=true"
```

**Option 2: Temporarily skip Traefik IAM bindings**
If you need to apply terraform-home before terraform-labs, you can temporarily comment out the Traefik IAM bindings in `iap.tf`:
- Comment out `google_cloud_run_v2_service_iam_member.traefik_seo_access`
- Comment out `google_cloud_run_v2_service_iam_member.traefik_index_access`

Then uncomment them after terraform-labs is applied.

## Architecture Notes

### What Terraform Manages

- ✅ **Service Accounts**: All service accounts and their IAM roles
- ✅ **IAM Bindings**: Access control for Cloud Run services
- ✅ **Infrastructure**: Artifact Registry, Firestore, Storage, VPC connectors
- ✅ **Project APIs**: Required GCP APIs

### What Terraform Does NOT Manage

- ❌ **Cloud Run Services**: Managed by GitHub Actions workflows (tracked in state with `lifecycle { ignore_changes = all }`)
- ❌ **Service Account Keys**: Created using `gcloud` and managed via scripts in `pcioasis-ops/secrets`
- ❌ **Container Images**: Built and pushed by GitHub Actions workflows

### Deployment Order

For a fresh production deployment:

1. **terraform-labs** (creates Traefik service account)
2. **terraform-home** (creates home infrastructure and grants Traefik access)
3. **GitHub Actions** (deploys Cloud Run services)

For importing existing production:

1. **terraform-home** (import existing resources)
2. **terraform-labs** (if Traefik doesn't exist yet, or import if it does)
3. **GitHub Actions** (continues managing Cloud Run services)

## Verification

After applying, verify the state:

```bash
# List all resources in state
terraform state list

# Check service accounts
gcloud iam service-accounts list --project=labs-home-prd

# Check IAM bindings
gcloud run services get-iam-policy home-index-prd \
  --region=us-central1 \
  --project=labs-home-prd
```

## Differences from Staging

Production and staging should be almost identical, with these differences:

1. **Public Access**: Production services have `allUsers` access, staging is restricted to groups
2. **Domain**: Production uses `labs.pcioasis.com`, staging uses `labs.stg.pcioasis.com`
3. **State Bucket**: Separate state buckets (`terraform-state-prd` vs `terraform-state-stg`)
4. **Project IDs**: `labs-home-prd` vs `labs-home-stg`

## Troubleshooting

### State Lock Issues

If Terraform is stuck with a state lock:

```bash
# Check for locks
gsutil ls gs://e-skimming-labs-terraform-state-prd/home/terraform-home/default.tflock

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Import Conflicts

If a resource is already in state but Terraform wants to create it:

```bash
# Check if resource is in state
terraform state list | grep <resource_name>

# If it's there, refresh state
terraform refresh -var="environment=prd" -var="deploy_services=true"
```

### Missing Dependencies

If you get errors about missing dependencies (like Traefik service account), check the deployment order section above.
