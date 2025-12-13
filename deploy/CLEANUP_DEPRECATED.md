# Cleaning Up Deprecated Resources

## Overview

After separating PRD and STG environments, some resources may need cleanup.

## 1. Old Shared Terraform State Bucket

If you previously used a shared state bucket `e-skimming-labs-terraform-state` (without environment suffix), you may need to:

### Check if old bucket exists:
```bash
gsutil ls gs://e-skimming-labs-terraform-state/ 2>/dev/null || echo "Bucket does not exist"
```

### If old bucket exists with state files:

**Option A: Migrate state to new environment-specific buckets**
```bash
# For each terraform directory, if you have old state:
cd deploy/terraform
# Backup old state
gsutil cp gs://e-skimming-labs-terraform-state/labs/terraform/default.tfstate /tmp/old-state-backup.json

# Initialize with new backend
terraform init -backend-config=backend-stg.conf -migrate-state
# Answer 'yes' when prompted to migrate
```

**Option B: Delete old bucket (if no longer needed)**
```bash
# WARNING: Only do this if you're sure you don't need the old state!
# First, verify no important state exists:
gsutil ls -r gs://e-skimming-labs-terraform-state/

# If safe to delete:
gsutil rm -r gs://e-skimming-labs-terraform-state/
```

## 2. Duplicate Firestore Database Resource

The `firestore.tf` file previously had a duplicate `google_firestore_database.labs_db_rules` resource. This has been removed. If it exists in your Terraform state:

```bash
cd deploy/terraform

# Check if it's in state
terraform state list | grep labs_db_rules

# If found, remove it (it was a duplicate)
terraform state rm google_firestore_database.labs_db_rules
```

## 3. Hardcoded Production Project IDs

Previously, some resources had hardcoded `labs-prd` references. These have been replaced with variables. If you see errors about hardcoded values:

- Check `terraform-home/cloud-run.tf` - should use `var.labs_project_id`
- Check `shared-components/home-index-service/main.go` - should read from `LABS_PROJECT_ID` env var

## 4. Old Environment-Specific Resources

If you're migrating from a shared setup to separate PRD/STG:

### Firestore Databases
- Old: Single database shared between environments
- New: Separate databases per environment
- Action: Create new databases in staging projects (Terraform will handle this)

### Service Accounts
- Old: Shared service accounts
- New: Environment-specific service accounts
- Action: Terraform will create new service accounts in staging projects

### Artifact Registry Repositories
- Old: Shared repositories
- New: Separate repositories per environment
- Action: Terraform will create new repositories in staging projects

## 5. Verification Checklist

After cleanup, verify:

```bash
# Check state buckets are separate
gsutil ls gs://e-skimming-labs-terraform-state-prd/
gsutil ls gs://e-skimming-labs-terraform-state-stg/

# Check no shared resources exist
# (except pcioasis-operations which is intentionally shared)

# Verify terraform state is clean
cd deploy/terraform
terraform state list
# Should not have any resources from other environments
```

## 6. Migration Steps

If migrating from shared to separate environments:

1. **Backup existing state** (if any)
2. **Create new environment-specific state buckets**
3. **Run terraform init with new backend configs**
4. **Import existing resources** (if needed) or let Terraform create new ones
5. **Verify separation** - no cross-environment dependencies
6. **Clean up old shared resources** (after verification)


