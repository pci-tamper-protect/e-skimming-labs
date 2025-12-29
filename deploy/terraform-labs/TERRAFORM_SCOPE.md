# Terraform Scope - What It Manages and What It Doesn't

## ⚠️ CRITICAL ARCHITECTURAL DECISION ⚠️

**Terraform MUST NEVER manage:**
- ❌ **Cloud Run services** - Managed by GitHub Actions workflows and `gcloud` commands
- ❌ **Service account keys** - Managed by `gcloud` commands and scripts

**Terraform SHOULD manage:**
- ✅ **Service accounts** (the accounts themselves, not keys)
- ✅ **IAM bindings** (roles, permissions, access control)
- ✅ **Storage buckets** (GCS buckets for data and logs)
- ✅ **VPC connectors** (for private Cloud Run services)
- ✅ **Artifact Registry repositories** (for Docker images)
- ✅ **Firestore databases and indexes** (for data storage)
- ✅ **Monitoring and alerting** (dashboards, alert policies)
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
- **Services affected**: `traefik`, `analytics_service`, and all lab services

### Service Account Keys
- **NOT in Terraform**: No `google_service_account_key` resources
- **Created via scripts**: Use `create-or-rotate-service-account-key.sh` in `pcioasis-ops/secrets`
- **Encrypted storage**: Keys stored in `.env.stg` / `.env.prd` with dotenvx encryption
- **Keys affected**: `labs_deploy_key` and any other service account keys

## Files to Check

When adding new infrastructure, verify:
- ✅ `service-accounts.tf` - Only service accounts, no keys
- ✅ `iap.tf` - IAM bindings using data sources, not resource references
- ✅ `cloud-run.tf` - **SHOULD NOT EXIST** or should only contain IAM bindings
- ✅ `traefik.tf` - Should use data sources for service references
- ✅ `outputs.tf` - Should use data sources for service URLs, not resources

## Migration Notes

If Cloud Run services are already in Terraform state:
```bash
# Remove from state (does NOT destroy the service)
terraform state rm google_cloud_run_v2_service.traefik[0]
terraform state rm google_cloud_run_v2_service.analytics_service[0]
```

If service account keys are in state:
```bash
# Remove from state (does NOT destroy the key)
terraform state rm google_service_account_key.labs_deploy_key
```

Then delete or comment out the resource definitions.
