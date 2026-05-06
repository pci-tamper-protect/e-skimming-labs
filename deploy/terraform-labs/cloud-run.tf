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

# C2 and extension services - private backends; Traefik SA needs run.invoker to forward requests
# These services are deployed via GitHub Actions; Terraform only manages IAM bindings

data "google_cloud_run_v2_service" "lab1_c2" {
  name     = "lab1-c2-${var.environment}"
  location = var.region
  project  = local.labs_project_id
}

data "google_cloud_run_v2_service" "lab2_c2" {
  name     = "lab2-c2-${var.environment}"
  location = var.region
  project  = local.labs_project_id
}

data "google_cloud_run_v2_service" "lab3_extension" {
  name     = "lab3-extension-${var.environment}"
  location = var.region
  project  = local.labs_project_id
}

resource "google_cloud_run_v2_service_iam_member" "lab1_c2_traefik_invoker" {
  location = data.google_cloud_run_v2_service.lab1_c2.location
  project  = data.google_cloud_run_v2_service.lab1_c2.project
  name     = data.google_cloud_run_v2_service.lab1_c2.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.traefik.email}"
}

resource "google_cloud_run_v2_service_iam_member" "lab2_c2_traefik_invoker" {
  location = data.google_cloud_run_v2_service.lab2_c2.location
  project  = data.google_cloud_run_v2_service.lab2_c2.project
  name     = data.google_cloud_run_v2_service.lab2_c2.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.traefik.email}"
}

resource "google_cloud_run_v2_service_iam_member" "lab3_extension_traefik_invoker" {
  location = data.google_cloud_run_v2_service.lab3_extension.location
  project  = data.google_cloud_run_v2_service.lab3_extension.project
  name     = data.google_cloud_run_v2_service.lab3_extension.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.traefik.email}"
}

# TODO: uncomment once lab4-c2-{env} is deployed (data sources require the service to exist at plan time)
# data "google_cloud_run_v2_service" "lab4_c2" {
#   name     = "lab4-c2-${var.environment}"
#   location = var.region
#   project  = local.labs_project_id
# }
# resource "google_cloud_run_v2_service_iam_member" "lab4_c2_traefik_invoker" {
#   location = data.google_cloud_run_v2_service.lab4_c2.location
#   project  = data.google_cloud_run_v2_service.lab4_c2.project
#   name     = data.google_cloud_run_v2_service.lab4_c2.name
#   role     = "roles/run.invoker"
#   member   = "serviceAccount:${google_service_account.traefik.email}"
# }

# Note: SEO and Index service IAM policies are in labs-home-prd project
# Note: Individual lab services are deployed via GitHub Actions workflow
# See TERRAFORM_SCOPE.md for architectural details
