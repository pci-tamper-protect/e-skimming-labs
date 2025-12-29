# IAM Access Control for Cloud Run Services
# NOTE: Cloud Run services themselves are NOT managed by Terraform
# They are deployed and managed by GitHub Actions workflows and gcloud commands
# Terraform ONLY manages IAM bindings for these services

# Data source to reference analytics service (managed by GitHub Actions)
data "google_cloud_run_v2_service" "analytics_service" {
  name     = "labs-analytics-${var.environment}"
  location = var.region
  project  = local.labs_project_id
}

# Analytics service - Protected backend, only callable by lab services
# IAM binding persists regardless of deploy_services flag
resource "google_cloud_run_v2_service_iam_member" "analytics_runtime_access" {
  location = data.google_cloud_run_v2_service.analytics_service.location
  project  = data.google_cloud_run_v2_service.analytics_service.project
  name     = data.google_cloud_run_v2_service.analytics_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.labs_runtime.email}"
}

# Note: SEO and Index service IAM policies are in labs-home-prd project
# Note: Individual lab services are deployed via GitHub Actions workflow
# See TERRAFORM_SCOPE.md for architectural details
