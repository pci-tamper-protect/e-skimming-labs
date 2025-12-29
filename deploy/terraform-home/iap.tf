# IAM-based Access Control for Staging Environment
# Restricts access to staging services to specific Google Groups
# Uses IAM bindings (not Load Balancer with IAP) to avoid costs

# IAM bindings for staging services - restrict to developer groups
# For staging: Only allow 2025-interns and core-eng groups
# For production: Keep public access (allUsers) - configured in cloud-run.tf

# Local variable for staging developer groups (used across multiple IAM bindings)
locals {
  staging_developer_groups = [
    "group:2025-interns@pcioasis.com",
    "group:core-eng@pcioasis.com"
  ]
}

# Data sources to look up services that may be deployed by GitHub Actions
# This allows IAM bindings to work even when deploy_services=false
# Available for both staging and production environments
data "google_cloud_run_v2_service" "home_seo_service" {
  count    = 1
  name     = "home-seo-${var.environment}"
  location = var.region
  project  = local.home_project_id
}

data "google_cloud_run_v2_service" "home_index_service" {
  count    = 1
  name     = "home-index-${var.environment}"
  location = var.region
  project  = local.home_project_id
}

# SEO Service - Staging access restricted to groups
# Note: IAM bindings are managed independently of deploy_services to ensure they persist
# Uses data source to reference services that may be deployed by GitHub Actions
resource "google_cloud_run_v2_service_iam_member" "seo_stg_group_access" {
  for_each = var.environment == "stg" ? toset(local.staging_developer_groups) : toset([])

  location = data.google_cloud_run_v2_service.home_seo_service[0].location
  project  = data.google_cloud_run_v2_service.home_seo_service[0].project
  name     = data.google_cloud_run_v2_service.home_seo_service[0].name
  role     = "roles/run.invoker"
  member   = each.value
}

# Index Service - Staging access restricted to groups
# Note: IAM bindings are managed independently of deploy_services to ensure they persist
# Uses data source to reference services that may be deployed by GitHub Actions
resource "google_cloud_run_v2_service_iam_member" "index_stg_group_access" {
  for_each = var.environment == "stg" ? toset(local.staging_developer_groups) : toset([])

  location = data.google_cloud_run_v2_service.home_index_service[0].location
  project  = data.google_cloud_run_v2_service.home_index_service[0].project
  name     = data.google_cloud_run_v2_service.home_index_service[0].name
  role     = "roles/run.invoker"
  member   = each.value
}

# Additional user access for staging services (beyond groups)
# Note: IAM bindings are managed independently of deploy_services to ensure they persist
# Uses data source to reference services that may be deployed by GitHub Actions
resource "google_cloud_run_v2_service_iam_member" "index_stg_user_access" {
  for_each = var.environment == "stg" ? toset(var.additional_allowed_users) : toset([])

  location = data.google_cloud_run_v2_service.home_index_service[0].location
  project  = data.google_cloud_run_v2_service.home_index_service[0].project
  name     = data.google_cloud_run_v2_service.home_index_service[0].name
  role     = "roles/run.invoker"
  member   = "user:${each.value}"
}

resource "google_cloud_run_v2_service_iam_member" "seo_stg_user_access" {
  for_each = var.environment == "stg" ? toset(var.additional_allowed_users) : toset([])

  location = data.google_cloud_run_v2_service.home_seo_service[0].location
  project  = data.google_cloud_run_v2_service.home_seo_service[0].project
  name     = data.google_cloud_run_v2_service.home_seo_service[0].name
  role     = "roles/run.invoker"
  member   = "user:${each.value}"
}

# Grant Traefik service account permission to invoke home services
# Traefik acts as a reverse proxy and needs to call these services on behalf of users
# This allows Traefik to route requests to home services without requiring user authentication
# Note: Traefik service account is created in terraform-labs project
# If the service account doesn't exist yet, apply terraform-labs first, then re-run terraform-home
data "google_project" "labs_project" {
  project_id = var.environment == "prd" ? "labs-prd" : "labs-stg"
}

# Traefik service account from labs project needs invoker access to home services
# Note: This requires the Traefik service account to exist (created by terraform-labs)
# If you get an error that the service account doesn't exist:
#   1. Apply terraform-labs first to create the Traefik service account
#   2. Then re-run terraform-home to create these IAM bindings
resource "google_cloud_run_v2_service_iam_member" "traefik_seo_access" {
  location = data.google_cloud_run_v2_service.home_seo_service[0].location
  project  = data.google_cloud_run_v2_service.home_seo_service[0].project
  name     = data.google_cloud_run_v2_service.home_seo_service[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:traefik-${var.environment}@${data.google_project.labs_project.project_id}.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service_iam_member" "traefik_index_access" {
  location = data.google_cloud_run_v2_service.home_index_service[0].location
  project  = data.google_cloud_run_v2_service.home_index_service[0].project
  name     = data.google_cloud_run_v2_service.home_index_service[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:traefik-${var.environment}@${data.google_project.labs_project.project_id}.iam.gserviceaccount.com"
}
