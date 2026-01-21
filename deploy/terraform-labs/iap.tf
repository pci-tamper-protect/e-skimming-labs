# IAM-based Access Control for Staging Environment
# Restricts access to staging services to specific Google Groups
# Uses IAM bindings (not Load Balancer with IAP) to avoid costs

# IAM bindings for staging services - restrict to developer groups
# For staging: Only allow 2025-interns and core-eng groups
# For production: Keep public access (allUsers) - configured in cloud-run.tf

# Analytics Service - Staging access restricted to groups
# Uses data source from cloud-run.tf (service managed by GitHub Actions)
# Note: IAM bindings are managed independently of deploy_services to ensure they persist
# Service is referenced via data source (managed by GitHub Actions)
resource "google_cloud_run_v2_service_iam_member" "analytics_stg_group_access" {
  for_each = var.environment == "stg" ? toset([
    "group:2025-interns@pcioasis.com",
    "group:core-eng@pcioasis.com"
  ]) : toset([])

  location = data.google_cloud_run_v2_service.analytics_service.location
  project  = data.google_cloud_run_v2_service.analytics_service.project
  name     = data.google_cloud_run_v2_service.analytics_service.name
  role     = "roles/run.invoker"
  member   = each.value
}

# Note: Individual lab services are deployed via GitHub Actions workflow
# They are configured with --no-allow-unauthenticated for staging
# and group access is granted in the workflow (see deploy_labs.yml)
