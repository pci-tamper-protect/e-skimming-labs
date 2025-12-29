# IAM Access Control for Cloud Run Services
# NOTE: Cloud Run services themselves are NOT managed by Terraform
# They are deployed and managed by GitHub Actions workflows and gcloud commands
# Terraform ONLY manages IAM bindings for these services

# IAM access control - environment-specific
# Production: Public access (allUsers)
# Staging: Restricted to developer groups (configured in iap.tf)
# Services are referenced via data sources (see iap.tf)

resource "google_cloud_run_v2_service_iam_member" "home_seo_public" {
  count    = var.environment == "prd" ? 1 : 0
  location = data.google_cloud_run_v2_service.home_seo_service[0].location
  project  = data.google_cloud_run_v2_service.home_seo_service[0].project
  name     = data.google_cloud_run_v2_service.home_seo_service[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "home_index_public" {
  count    = var.environment == "prd" ? 1 : 0
  location = data.google_cloud_run_v2_service.home_index_service[0].location
  project  = data.google_cloud_run_v2_service.home_index_service[0].project
  name     = data.google_cloud_run_v2_service.home_index_service[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Note: For staging (stg), access is restricted via IAM group bindings in iap.tf
# Groups: 2025-interns@pcioasis.com, core-eng@pcioasis.com
#
# IMPORTANT: Cloud Run services are deployed by GitHub Actions, NOT Terraform
# See TERRAFORM_SCOPE.md for architectural details
