# Terraform Scope - What It Manages and What It Doesn't

## ⚠️ CRITICAL ARCHITECTURAL DECISION ⚠️

**Terraform MUST NEVER manage:**
- ❌ **Cloud Run services** - Managed by GitHub Actions workflows and `gcloud` commands
- ❌ **Service account keys** - Managed by `gcloud` commands and scripts

**Terraform SHOULD manage:**
- ✅ **Service accounts** (the accounts themselves, not keys)
- ✅ **IAM bindings** (roles, permissions, access control)
- ✅ **Storage buckets** (GCS buckets for assets)
- ✅ **VPC connectors** (for private Cloud Run services)
- ✅ **Artifact Registry repositories** (for Docker images)
- ✅ **Firestore databases** (for data storage)
- ✅ **Other static infrastructure** (APIs, networks, etc.)

## Why This Separation?

1. **Cloud Run services** change frequently (code deployments, config updates)
   - GitHub Actions workflows handle deployments
   - `gcloud run deploy` commands manage service configuration
   - Terraform would cause conflicts and unnecessary state management

2. **Service account keys** are secrets that should be:
   - Created on-demand via `gcloud` commands
   - Rotated regularly
   - Never stored in Terraform state
   - Managed by scripts that handle encryption and GitHub secrets

3. **Static infrastructure** (SAs, IAM, storage) changes infrequently
   - Perfect for Terraform's declarative model
   - IAM bindings need to persist regardless of service deployments
   - Storage buckets and VPC connectors are long-lived resources

## Implementation Details

### Cloud Run Services
- **NOT in Terraform**: Remove `google_cloud_run_v2_service` resources
- **Use data sources**: Reference services via `data "google_cloud_run_v2_service"` for IAM bindings
- **IAM bindings**: Terraform manages IAM, not the services themselves

### Service Account Keys
- **NOT in Terraform**: No `google_service_account_key` resources
- **Created via scripts**: Use `create-or-rotate-service-account-key.sh`
- **Encrypted storage**: Keys stored in `.env.stg` / `.env.prd` with dotenvx encryption

## Files to Check

When adding new infrastructure, verify:
- ✅ `service-accounts.tf` - Only service accounts, no keys
- ✅ `iap.tf` - IAM bindings using data sources, not resource references
- ✅ `cloud-run.tf` - **SHOULD NOT EXIST** or should only contain IAM bindings
- ✅ `outputs.tf` - Should use data sources for service URLs, not resources

## Migration Notes

If Cloud Run services are already in Terraform state:
```bash
# Remove from state (does NOT destroy the service)
terraform state rm google_cloud_run_v2_service.home_seo_service[0]
terraform state rm google_cloud_run_v2_service.home_index_service[0]
```

Then delete or comment out the resource definitions in `cloud-run.tf`.

