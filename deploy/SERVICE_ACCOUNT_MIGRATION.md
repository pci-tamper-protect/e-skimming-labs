# Service Account Migration: github-actions → labs-deploy-sa / home-deploy-sa

## Overview

The project has migrated from using over-privileged `github-actions@...` service accounts to project-scoped service accounts managed by Terraform. This migration addresses two key security improvements:

1. **Reduced Privileges**: From `roles/run.admin` to `roles/run.developer` (principle of least privilege)
2. **Environment Isolation**: From potentially cross-environment access to strict project-scoped access

### Migration Benefits

- **Security**: Each environment has its own service account with no cross-environment access
- **Least Privilege**: Reduced permissions from admin to developer role
- **Explicit Permissions**: Repository-level Artifact Registry bindings instead of only project-level
- **Infrastructure as Code**: Service accounts managed by Terraform for consistency and auditability

### New Service Account Structure

- **Labs Staging**: `labs-deploy-sa@labs-stg.iam.gserviceaccount.com`
- **Labs Production**: `labs-deploy-sa@labs-prd.iam.gserviceaccount.com`
- **Home Staging**: `home-deploy-sa@labs-home-stg.iam.gserviceaccount.com`
- **Home Production**: `home-deploy-sa@labs-home-prd.iam.gserviceaccount.com`

## Service Account Comparison

### Old Service Accounts (`github-actions@...`)

**Created by**: `deploy/create-service-accounts.sh`

**Projects**:
- `github-actions@labs-stg.iam.gserviceaccount.com`
- `github-actions@labs-prd.iam.gserviceaccount.com`
- `github-actions@labs-home-stg.iam.gserviceaccount.com`
- `github-actions@labs-home-prd.iam.gserviceaccount.com`

**⚠️ Security Issues**:
1. **Over-Privileged**: Had `roles/run.admin` (full Cloud Run admin, can delete services)
2. **Potential Cross-Environment Access**: A single GitHub secret (`GCP_LABS_SA_KEY`) might have been used for both environments, meaning one service account could access both staging and production
3. **Broad Permissions**: Only project-level Artifact Registry permissions (no explicit repository bindings)

**Permissions**:
- `roles/run.admin` - Full Cloud Run admin (can delete services) ⚠️ **Over-privileged**
- `roles/artifactregistry.writer` - Push images (project level only)
- `roles/iam.serviceAccountUser` - Use service accounts

**Additional Permissions** (from `fix-terraform-state-permissions.sh`):
- `roles/storage.objectAdmin` on Terraform state bucket

**⚠️ Cross-Environment Risk**: If the same GitHub secret was used for both environments, a compromised key could access both staging and production resources.

### New Service Accounts (`labs-deploy-sa` / `home-deploy-sa`)

**Created by**: Terraform (`terraform-labs/service-accounts.tf`, `terraform-home/service-accounts.tf`)

**Projects**:
- `labs-deploy-sa@labs-stg.iam.gserviceaccount.com`
- `labs-deploy-sa@labs-prd.iam.gserviceaccount.com`
- `home-deploy-sa@labs-home-stg.iam.gserviceaccount.com`
- `home-deploy-sa@labs-home-prd.iam.gserviceaccount.com`

**Permissions**:
- `roles/run.developer` - Deploy and manage Cloud Run services (less privileged than admin)
- `roles/artifactregistry.writer` - Push images (project level)
- `roles/artifactregistry.writer` - Push images (repository level - **explicit binding**)
- `roles/iam.serviceAccountUser` - Use service accounts
- `roles/storage.objectViewer` - Read storage objects
- `roles/storage.objectCreator` - Upload deployment artifacts

**Additional Permissions** (from `fix-terraform-state-permissions.sh`):
- `roles/storage.objectAdmin` on Terraform state bucket
- `roles/artifactregistry.writer` on Artifact Registry repositories (explicit repository-level binding)

## Key Differences

### 1. Environment Isolation (Critical Security Improvement)

**Old Approach** (⚠️ Security Risk):
- Potentially used a single GitHub secret (`GCP_LABS_SA_KEY`) for both environments
- One service account key could access both staging and production
- Risk: Compromised key = access to both environments

**New Approach** (✅ Secure):
- Separate service accounts per environment:
  - `labs-deploy-sa@labs-stg.iam.gserviceaccount.com` (staging only)
  - `labs-deploy-sa@labs-prd.iam.gserviceaccount.com` (production only)
- Each environment requires its own service account key
- **Impact**: Complete environment isolation - compromised staging key cannot access production

### 2. Cloud Run Permissions

- **Old**: `roles/run.admin` (can delete services) ⚠️ **Over-privileged**
- **New**: `roles/run.developer` (cannot delete services, but can deploy/update)
- **Impact**: New SA follows principle of least privilege - cannot accidentally delete production services

### 3. Artifact Registry Permissions

- **Old**: Only project-level `roles/artifactregistry.writer`
- **New**: Both project-level AND repository-level `roles/artifactregistry.writer` (explicit bindings)
- **Impact**: New SA has explicit repository-level permissions (more secure, easier to audit)

### 4. Storage Permissions

- **Old**: Only Terraform state bucket access
- **New**: Terraform state bucket + `storage.objectViewer` + `storage.objectCreator` at project level
- **Impact**: New SA has broader storage permissions for deployment artifacts

### 5. Infrastructure Management

- **Old**: Service accounts created manually via scripts, not version-controlled
- **New**: Service accounts managed by Terraform (Infrastructure as Code)
- **Impact**: Consistent, auditable, and reproducible service account configuration

## Migration Steps

### ⚠️ Important: Environment-Scoped Secrets

The GitHub workflow (`deploy_labs.yml`) uses environment-specific service accounts based on the branch:
- **Staging branch (`stg`)**: Uses `labs-stg` and `labs-home-stg` projects
- **Production branch (`main`)**: Uses `labs-prd` and `labs-home-prd` projects

However, the workflow currently uses the same secrets (`GCP_LABS_SA_KEY`, `GCP_HOME_SA_KEY`) for both environments. This is a security risk if the old service account had access to both environments.

### 1. Create Environment-Specific Service Accounts (via Terraform)

**⚠️ CRITICAL**: The production environment service accounts must be created separately via Terraform. They are **NOT** automatically created when you create staging service accounts. Each environment has completely separate service accounts that must be provisioned independently.

**Production service accounts that must be created**:
- `labs-deploy-sa@labs-prd.iam.gserviceaccount.com` (in `labs-prd` project)
- `home-deploy-sa@labs-home-prd.iam.gserviceaccount.com` (in `labs-home-prd` project)

These are **different** service accounts from the staging ones (`labs-deploy-sa@labs-stg.iam.gserviceaccount.com` and `home-deploy-sa@labs-home-stg.iam.gserviceaccount.com`).

**Methods to create production service accounts**:

You can create production service accounts using either:

**Option A: Using deployment scripts (Recommended)**

The deployment scripts automatically create service accounts when run against production:

```bash
# For labs project (creates labs-deploy-sa@labs-prd.iam.gserviceaccount.com)
cd deploy
# Set up .env for production (or use .env.prd)
ln -s .env.prd .env  # or create .env with LABS_PROJECT_ID=labs-prd
./deploy-labs.sh

# For home project (creates home-deploy-sa@labs-home-prd.iam.gserviceaccount.com)
# Set up .env for production with HOME_PROJECT_ID=labs-home-prd
./deploy-home.sh
```

**Option B: Using Terraform directly**

```bash
# For staging - Labs
cd deploy/terraform-labs
terraform init -backend-config=backend-stg.conf
terraform apply -var="environment=stg"

cd ../terraform-home
terraform init -backend-config=backend-stg.conf
terraform apply -var="environment=stg"

# ⚠️ CRITICAL: For production - these must be created separately
cd ../terraform-labs
terraform init -backend-config=backend-prd.conf
terraform apply -var="environment=prd"

cd ../terraform-home
terraform init -backend-config=backend-prd.conf
terraform apply -var="environment=prd"
```

**⚠️ Production Service Accounts**: The production environment (`labs-prd` and `labs-home-prd`) requires separate Terraform runs (via scripts or direct terraform apply) to generate the production-scoped service accounts:
- `labs-deploy-sa@labs-prd.iam.gserviceaccount.com`
- `home-deploy-sa@labs-home-prd.iam.gserviceaccount.com`

**Note**: The deployment scripts (`deploy/deploy-labs.sh` and `deploy/deploy-home.sh`) automatically determine the environment from the project ID (if it ends with `-prd`, they use production). They will create the service accounts as part of the Terraform apply process.

These are **different** service accounts from the staging ones and must be created independently. Do not assume that creating staging service accounts will also create production ones.

### 2. Create Service Account Keys for Each Environment

**⚠️ Important**: Production service account keys must be generated separately from staging keys. Each environment has its own service accounts, so you need to create keys for each environment independently.

**Option A: Use Environment-Specific Secrets (Recommended)**

Create separate secrets for each environment:

```bash
# Staging - Labs
gcloud iam service-accounts keys create /tmp/labs-deploy-stg-key.json \
  --iam-account=labs-deploy-sa@labs-stg.iam.gserviceaccount.com \
  --project=labs-stg

gh secret set GCP_LABS_SA_KEY_STG --body "$(cat /tmp/labs-deploy-stg-key.json)" \
  --repo pci-tamper-protect/e-skimming-labs

# Production - Labs
gcloud iam service-accounts keys create /tmp/labs-deploy-prd-key.json \
  --iam-account=labs-deploy-sa@labs-prd.iam.gserviceaccount.com \
  --project=labs-prd

gh secret set GCP_LABS_SA_KEY_PRD --body "$(cat /tmp/labs-deploy-prd-key.json)" \
  --repo pci-tamper-protect/e-skimming-labs

# Staging - Home
gcloud iam service-accounts keys create /tmp/home-deploy-stg-key.json \
  --iam-account=home-deploy-sa@labs-home-stg.iam.gserviceaccount.com \
  --project=labs-home-stg

gh secret set GCP_HOME_SA_KEY_STG --body "$(cat /tmp/home-deploy-stg-key.json)" \
  --repo pci-tamper-protect/e-skimming-labs

# Production - Home
gcloud iam service-accounts keys create /tmp/home-deploy-prd-key.json \
  --iam-account=home-deploy-sa@labs-home-prd.iam.gserviceaccount.com \
  --project=labs-home-prd

gh secret set GCP_HOME_SA_KEY_PRD --body "$(cat /tmp/home-deploy-prd-key.json)" \
  --repo pci-tamper-protect/e-skimming-labs

# Clean up
rm /tmp/*-deploy-*-key.json
```

**Option B: Use Single Secret (Less Secure, but Simpler)**

If you want to keep using a single secret, use the production key (it will work for staging if both environments use the same key, but this reduces isolation):

```bash
# For production (most restrictive)
gcloud iam service-accounts keys create /tmp/labs-deploy-key.json \
  --iam-account=labs-deploy-sa@labs-prd.iam.gserviceaccount.com \
  --project=labs-prd

gh secret set GCP_LABS_SA_KEY --body "$(cat /tmp/labs-deploy-key.json)" \
  --repo pci-tamper-protect/e-skimming-labs

# For home production
gcloud iam service-accounts keys create /tmp/home-deploy-key.json \
  --iam-account=home-deploy-sa@labs-home-prd.iam.gserviceaccount.com \
  --project=labs-home-prd

gh secret set GCP_HOME_SA_KEY --body "$(cat /tmp/home-deploy-key.json)" \
  --repo pci-tamper-protect/e-skimming-labs

rm /tmp/*-deploy-key.json
```

**⚠️ Important Notes**:

1. **Production Keys Must Be Generated Separately**: Production service accounts (`labs-deploy-sa@labs-prd.iam.gserviceaccount.com` and `home-deploy-sa@labs-home-prd.iam.gserviceaccount.com`) are separate from staging and require their own keys. Do not reuse staging keys for production.

2. **Option B Reduces Isolation**: Option B reduces environment isolation. If using Option B, ensure the workflow selects the correct service account based on the environment. The current workflow uses the same secret for both environments, which means you need to ensure the service account key matches the environment being deployed to.

3. **Verify Service Account Exists**: Before creating keys, verify the service accounts exist:
   ```bash
   # Verify staging
   gcloud iam service-accounts describe labs-deploy-sa@labs-stg.iam.gserviceaccount.com --project=labs-stg
   gcloud iam service-accounts describe home-deploy-sa@labs-home-stg.iam.gserviceaccount.com --project=labs-home-stg
   
   # Verify production (these must exist separately)
   gcloud iam service-accounts describe labs-deploy-sa@labs-prd.iam.gserviceaccount.com --project=labs-prd
   gcloud iam service-accounts describe home-deploy-sa@labs-home-prd.iam.gserviceaccount.com --project=labs-home-prd
   ```

### 3. Grant Missing Permissions

Run the updated fix script to ensure all permissions are granted for each environment:

```bash
# For staging
cd deploy
export LABS_PROJECT_ID=labs-stg
export HOME_PROJECT_ID=labs-home-stg
export ENVIRONMENT=stg
./fix-terraform-state-permissions.sh

# For production
export LABS_PROJECT_ID=labs-prd
export HOME_PROJECT_ID=labs-home-prd
export ENVIRONMENT=prd
./fix-terraform-state-permissions.sh
```

This script now grants:
- Terraform state bucket access to both old and new service accounts (per environment)
- Repository-level Artifact Registry permissions to new service accounts (per environment)
- Ensures complete environment isolation

### 4. Verify Permissions and Environment Isolation

Verify that service accounts are properly scoped to their environments:

```bash
# Verify staging service accounts
cd deploy
./verify-and-fix-gha-service-account.sh stg

# Verify production service accounts (if needed)
./verify-and-fix-gha-service-account.sh prd
```

**Verify Environment Isolation**:

Ensure that staging service accounts cannot access production resources:

```bash
# Try to access production with staging service account (should fail)
gcloud config set project labs-prd
gcloud auth activate-service-account labs-deploy-sa@labs-stg.iam.gserviceaccount.com \
  --key-file=/tmp/stg-key.json

# This should fail with permission denied
gcloud run services list --project=labs-prd
```

**Expected Result**: Permission denied - staging service account cannot access production resources.

## Security Benefits of Migration

### Before Migration (Old `github-actions@...`)

**Risks**:
1. ⚠️ Single service account key potentially used for both environments
2. ⚠️ Over-privileged (`roles/run.admin` can delete services)
3. ⚠️ No explicit repository-level permissions
4. ⚠️ Manual management (not version-controlled)

**Impact of Compromise**:
- If a single key was used: Access to both staging AND production
- Could delete production services
- Could push malicious images to production

### After Migration (New `labs-deploy-sa@...` / `home-deploy-sa@...`)

**Improvements**:
1. ✅ Environment-scoped service accounts (staging cannot access production)
2. ✅ Reduced privileges (`roles/run.developer` cannot delete services)
3. ✅ Explicit repository-level permissions (easier to audit)
4. ✅ Infrastructure as Code (Terraform-managed, version-controlled)

**Impact of Compromise**:
- Staging key compromise: Only affects staging environment
- Production key compromise: Only affects production environment
- Cannot delete services (requires manual intervention)
- All changes are auditable via Terraform

## Troubleshooting

### Issue: "Permission denied" when pushing to Artifact Registry

**Cause**: GitHub secret contains key for old `github-actions@...` service account, or new SA lacks repository-level permissions.

**Solution**:
1. Verify the service account has repository-level permissions:
   ```bash
   gcloud artifacts repositories get-iam-policy e-skimming-labs \
     --location=us-central1 \
     --project=labs-stg \
     --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:labs-deploy-sa@labs-stg.iam.gserviceaccount.com"
   ```

2. If missing, run Terraform apply or manually grant:
   ```bash
   gcloud artifacts repositories add-iam-policy-binding e-skimming-labs \
     --location=us-central1 \
     --project=labs-stg \
     --member="serviceAccount:labs-deploy-sa@labs-stg.iam.gserviceaccount.com" \
     --role="roles/artifactregistry.writer"
   ```

3. Update GitHub secret with correct service account key (see Migration Steps #1)

### Issue: Cannot delete Cloud Run services

**Cause**: New service account has `roles/run.developer` instead of `roles/run.admin`.

**Solution**: This is intentional (principle of least privilege). If deletion is needed:
- Use a user account with `roles/run.admin`
- Or temporarily grant `roles/run.admin` to the service account for deletion operations

### Issue: Workflow fails with "service account not found" for wrong environment

**Cause**: GitHub secret contains a key for a different environment's service account.

**Solution**:
1. Verify which environment the workflow is deploying to (check workflow logs)
2. Ensure the GitHub secret contains the key for the correct environment's service account
3. If using environment-specific secrets, update the workflow to use the correct secret based on the environment

### Issue: Service account can access both staging and production

**Cause**: Old service account key still in use, or incorrect IAM bindings.

**Solution**:
1. Verify the service account key is for the correct environment:
   ```bash
   # Extract service account email from key
   cat /path/to/key.json | jq -r '.client_email'
   ```
2. Ensure the service account only has permissions in its own project:
   ```bash
   # Check labs-stg service account permissions (should only show labs-stg)
   gcloud projects get-iam-policy labs-stg \
     --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:labs-deploy-sa@labs-stg.iam.gserviceaccount.com"
   
   # Check labs-prd service account permissions (should only show labs-prd)
   gcloud projects get-iam-policy labs-prd \
     --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:labs-deploy-sa@labs-prd.iam.gserviceaccount.com"
   ```
3. If cross-environment access is found, remove it:
   ```bash
   # Remove staging SA from production project (if incorrectly granted)
   gcloud projects remove-iam-policy-binding labs-prd \
     --member="serviceAccount:labs-deploy-sa@labs-stg.iam.gserviceaccount.com" \
     --role="roles/run.developer"
   ```

## Files Updated

- `deploy/fix-terraform-state-permissions.sh` - Now grants permissions to both old and new service accounts
- `deploy/terraform-labs/service-accounts.tf` - Defines new `labs-deploy-sa` with repository-level Artifact Registry permissions
- `deploy/terraform-home/service-accounts.tf` - Defines new `home-deploy-sa` with repository-level Artifact Registry permissions

## Cleanup: Removing Old Service Accounts

After successful migration and verification, the old `github-actions@...` service accounts can be removed for better security:

### Prerequisites

1. ✅ All deployments are using new service accounts
2. ✅ GitHub secrets updated to new service account keys
3. ✅ All workflows tested and working
4. ✅ No dependencies on old service accounts

### Removal Steps

```bash
# For each environment, remove the old service account

# Staging - Labs
gcloud iam service-accounts delete github-actions@labs-stg.iam.gserviceaccount.com \
  --project=labs-stg

# Production - Labs
gcloud iam service-accounts delete github-actions@labs-prd.iam.gserviceaccount.com \
  --project=labs-prd

# Staging - Home
gcloud iam service-accounts delete github-actions@labs-home-stg.iam.gserviceaccount.com \
  --project=labs-home-stg

# Production - Home
gcloud iam service-accounts delete github-actions@labs-home-prd.iam.gserviceaccount.com \
  --project=labs-home-prd
```

**⚠️ Warning**: Only delete old service accounts after confirming:
- All GitHub Actions workflows are using new service accounts
- No manual scripts or processes depend on the old accounts
- All IAM bindings have been migrated to new accounts

### Verification After Cleanup

```bash
# Verify old service accounts are deleted
gcloud iam service-accounts list --project=labs-stg | grep github-actions
gcloud iam service-accounts list --project=labs-prd | grep github-actions

# Should return no results
```

## Summary

This migration provides:
- ✅ **Environment Isolation**: Staging and production completely isolated
- ✅ **Reduced Privileges**: From admin to developer role
- ✅ **Explicit Permissions**: Repository-level bindings for better security
- ✅ **Infrastructure as Code**: Terraform-managed, version-controlled
- ✅ **Better Auditability**: All changes tracked in Terraform state

The old `github-actions@...` service accounts were over-privileged and potentially had cross-environment access. The new service accounts are project-scoped, follow the principle of least privilege, and are managed as infrastructure code.

### ⚠️ Critical Reminder: Production Service Accounts

**Production service accounts must be created separately** via Terraform. They are **NOT** automatically created when you provision staging. Each environment requires its own Terraform apply:

- **Staging**: `terraform apply -var="environment=stg"` creates:
  - `labs-deploy-sa@labs-stg.iam.gserviceaccount.com`
  - `home-deploy-sa@labs-home-stg.iam.gserviceaccount.com`

- **Production**: `terraform apply -var="environment=prd"` creates:
  - `labs-deploy-sa@labs-prd.iam.gserviceaccount.com`
  - `home-deploy-sa@labs-home-prd.iam.gserviceaccount.com`

These are **completely separate** service accounts in different GCP projects. Production keys must be generated independently from staging keys. Do not assume that creating staging service accounts will also create production ones.

