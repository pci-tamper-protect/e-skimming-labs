# IAM-based Access Control for Staging Environment
# Restricts access to staging services to specific Google Groups
# Uses IAM bindings (not Load Balancer with IAP) to avoid costs

# IAM bindings for staging services - restrict to developer groups
# For staging: Only allow 2025-interns and core-eng groups
# For production: Keep public access (allUsers) - configured in cloud-run.tf

# SEO Service - Staging access restricted to groups
resource "google_cloud_run_v2_service_iam_member" "seo_stg_group_access" {
  for_each = var.deploy_services && var.environment == "stg" ? toset([
    "group:2025-interns@pcioasis.com",
    "group:core-eng@pcioasis.com"
  ]) : toset([])

  location = google_cloud_run_v2_service.home_seo_service[0].location
  project  = google_cloud_run_v2_service.home_seo_service[0].project
  name     = google_cloud_run_v2_service.home_seo_service[0].name
  role     = "roles/run.invoker"
  member   = each.value

  depends_on = [
    google_cloud_run_v2_service.home_seo_service
  ]
}

# Index Service - Staging access restricted to groups
resource "google_cloud_run_v2_service_iam_member" "index_stg_group_access" {
  for_each = var.deploy_services && var.environment == "stg" ? toset([
    "group:2025-interns@pcioasis.com",
    "group:core-eng@pcioasis.com"
  ]) : toset([])

  location = google_cloud_run_v2_service.home_index_service[0].location
  project  = google_cloud_run_v2_service.home_index_service[0].project
  name     = google_cloud_run_v2_service.home_index_service[0].name
  role     = "roles/run.invoker"
  member   = each.value

  depends_on = [
    google_cloud_run_v2_service.home_index_service
  ]
}

