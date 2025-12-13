# IAM-based Access Control for Staging Environment

This document describes how IAM-based access control is configured to restrict access to staging services to only developers in the `2025-interns` and `core-eng` groups.

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

### 1. Apply Terraform Changes

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

1. **As a group member**: Should be able to access staging URLs
2. **As a non-member**: Should receive 403 Forbidden

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

