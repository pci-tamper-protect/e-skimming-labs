# Traefik Reverse Proxy Service for Labs
# This service provides unified path-based routing for all lab services

# Service Account for Traefik
resource "google_service_account" "traefik" {
  account_id   = "traefik-${var.environment}"
  display_name = "Traefik Reverse Proxy (${var.environment})"
  description  = "Service account for Traefik reverse proxy in ${var.environment}"
  project      = local.labs_project_id
}

# Grant Traefik permission to invoke other Cloud Run services
resource "google_project_iam_member" "traefik_invoker" {
  project = local.labs_project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.traefik.email}"
}

# Grant Traefik permission to pull images from Artifact Registry
resource "google_project_iam_member" "traefik_artifact_registry_reader" {
  project = local.labs_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.traefik.email}"
}

# Data source to reference Traefik service (managed by GitHub Actions)
data "google_cloud_run_v2_service" "traefik" {
  name     = "traefik-${var.environment}"
  location = var.region
  project  = local.labs_project_id
}

# Data sources to get project numbers for constructing URLs
data "google_project" "labs_project" {
  project_id = local.labs_project_id
}

data "google_project" "home_project" {
  project_id = local.home_project_id
}

# Public access for production, restricted for staging
resource "google_cloud_run_v2_service_iam_member" "traefik_public" {
  count    = var.environment == "prd" ? 1 : 0
  location = data.google_cloud_run_v2_service.traefik.location
  project  = data.google_cloud_run_v2_service.traefik.project
  name     = data.google_cloud_run_v2_service.traefik.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# For staging, grant access to developer groups
# Traefik is the single entry point - only it needs IAM protection
resource "google_cloud_run_v2_service_iam_member" "traefik_stg_group_access" {
  for_each = var.environment == "stg" ? toset([
    "group:2025-interns@pcioasis.com",
    "group:core-eng@pcioasis.com"
  ]) : toset([])

  location = data.google_cloud_run_v2_service.traefik.location
  project  = data.google_cloud_run_v2_service.traefik.project
  name     = data.google_cloud_run_v2_service.traefik.name
  role     = "roles/run.invoker"
  member   = each.value
}

# Domain mapping for Traefik service
# Managed in terraform-labs since Traefik service lives here
# NOTE: Domain mapping may be managed manually or by GitHub Actions
resource "google_cloud_run_domain_mapping" "traefik_domain" {
  count = 1

  name     = var.environment == "prd" ? "labs.pcioasis.com" : "labs.stg.pcioasis.com"
  location = var.region
  project  = local.labs_project_id

  metadata {
    namespace = local.labs_project_id
  }

  spec {
    route_name = data.google_cloud_run_v2_service.traefik.name
  }

  # Ignore changes to allow manual management if needed
  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    data.google_cloud_run_v2_service.traefik
  ]
}

# Output Traefik service URL
output "traefik_url" {
  description = "URL of the Traefik reverse proxy service (from data source, service managed by GitHub Actions)"
  value       = try(data.google_cloud_run_v2_service.traefik.uri, "Service not deployed yet")
}

output "traefik_domain" {
  description = "Custom domain for Traefik service"
  value       = var.environment == "prd" ? "https://labs.pcioasis.com" : "https://labs.stg.pcioasis.com"
}

output "traefik_service_account" {
  description = "Email of the Traefik service account"
  value       = google_service_account.traefik.email
}
