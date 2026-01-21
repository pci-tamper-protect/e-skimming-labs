# Removing Service Account Keys from Terraform State

## Overview

Service account keys should NOT be managed by Terraform. This guide shows how to safely remove them from Terraform state without destroying the actual keys in GCP.

## Why Remove Keys from Terraform?

- **Keys are credentials, not infrastructure** - They should be created on-demand with `gcloud`
- **Keys can be rotated** - Multiple keys can exist for the same service account
- **Security best practice** - Keys shouldn't be in Terraform state (which may be stored remotely)

## Step-by-Step Process

### Step 1: Remove Keys from Terraform State (Before Removing Code)

Run these commands **before** removing the resource definitions from code:

```bash
cd deploy/terraform-home

# Remove home_deploy_key from state (if it exists)
terraform state rm google_service_account_key.home_deploy_key 2>/dev/null || echo "Key not in state"

# Remove fbase_adm_sdk_runtime_key from state (if it exists)
terraform state rm google_service_account_key.fbase_adm_sdk_runtime_key 2>/dev/null || echo "Key not in state"
```

**What this does:**
- Removes the resources from Terraform's state file
- **Does NOT destroy the actual keys in GCP** - they remain intact
- Terraform will no longer track or manage these keys

### Step 2: Verify Keys Still Exist in GCP

```bash
# Check if keys still exist (they should!)
gcloud iam service-accounts keys list \
  --iam-account=home-deploy-sa@labs-home-stg.iam.gserviceaccount.com \
  --project=labs-home-stg

gcloud iam service-accounts keys list \
  --iam-account=fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com \
  --project=labs-home-stg
```

### Step 3: Remove Resource Definitions from Code

After removing from state, you can safely remove the resource definitions from `service-accounts.tf`:

```terraform
# Remove these blocks:
resource "google_service_account_key" "home_deploy_key" { ... }
resource "google_service_account_key" "fbase_adm_sdk_runtime_key" { ... }

# And remove these outputs:
output "home_deploy_key" { ... }
output "fbase_adm_sdk_runtime_key" { ... }
```

### Step 4: Verify Terraform Plan

After removing the code, run:

```bash
terraform plan
```

You should see:
- ✅ No changes (if keys were already removed from state)
- ✅ Or only the removal of the resource definitions (no destroy operations)

## Alternative: If Keys Are Already Removed from Code

If you've already removed the resource definitions from code but haven't removed them from state:

1. **Temporarily add them back** to the code (just the resource blocks, not outputs)
2. **Run `terraform state rm`** to remove from state
3. **Remove them from code again**

Or use `terraform state rm` with the full resource address:

```bash
# If the resources are no longer in code, use the full address
terraform state rm 'google_service_account_key.home_deploy_key'
terraform state rm 'google_service_account_key.fbase_adm_sdk_runtime_key'
```

## Important Notes

- **Keys remain in GCP** - Removing from Terraform state does NOT delete the keys
- **Keys can still be used** - All existing keys continue to work
- **New keys** - Create new keys using `gcloud` or the scripts in `pcioasis-ops/secrets`
- **State file** - The state file is updated locally and remotely (if using remote state)

## Verification

After completing the process:

```bash
# Verify keys are not in Terraform state
terraform state list | grep service_account_key
# Should return nothing

# Verify keys still exist in GCP
gcloud iam service-accounts keys list \
  --iam-account=home-deploy-sa@labs-home-stg.iam.gserviceaccount.com \
  --project=labs-home-stg
# Should show the keys still exist
```

## Troubleshooting

### Error: "Resource not found in state"

This means the key was never created by Terraform, or was already removed. This is fine - just proceed.

### Error: "Resource is managed by Terraform"

If you get this error, the resource is still in state. Use `terraform state rm` to remove it.

### Want to Delete the Keys?

If you actually want to delete the keys (not recommended unless rotating):

```bash
# List keys to get key IDs
gcloud iam service-accounts keys list \
  --iam-account=home-deploy-sa@labs-home-stg.iam.gserviceaccount.com \
  --project=labs-home-stg

# Delete a specific key (use the KEY_ID from above)
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=home-deploy-sa@labs-home-stg.iam.gserviceaccount.com \
  --project=labs-home-stg
```

**Note**: Only delete keys if you're rotating them and have created new ones first!
