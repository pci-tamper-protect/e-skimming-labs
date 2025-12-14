# Outputs for Home Page Project

output "project_id" {
  description = "The GCP project ID for home page"
  value       = local.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "artifact_registry_repository" {
  description = "The Artifact Registry repository URL for home page"
  value       = google_artifact_registry_repository.home_repo.name
}

output "firestore_database" {
  description = "The Firestore database name for home page"
  value       = google_firestore_database.home_db.name
}

output "storage_bucket_assets" {
  description = "The Cloud Storage bucket for home page assets"
  value       = google_storage_bucket.home_assets.name
}

output "seo_service_url" {
  description = "The SEO service URL"
  value       = var.deploy_services ? google_cloud_run_v2_service.home_seo_service[0].uri : "Service not deployed yet"
}

output "index_service_url" {
  description = "The Index service URL"
  value       = var.deploy_services ? google_cloud_run_v2_service.home_index_service[0].uri : "Service not deployed yet"
}

output "home_runtime_service_account" {
  description = "The home runtime service account email"
  value       = google_service_account.home_runtime.email
}

output "home_deploy_service_account" {
  description = "The home deploy service account email"
  value       = google_service_account.home_deploy.email
}

output "home_seo_service_account" {
  description = "The home SEO service account email"
  value       = google_service_account.home_seo.email
}

# GitHub Secrets (to be added manually)
output "github_secrets_instructions_home" {
  description = "Instructions for setting up GitHub secrets for home page"
  value       = <<-EOT
    Add the following secrets to your GitHub repository for HOME PAGE deployment:
    
    1. GCP_HOME_PROJECT_ID: ${local.project_id}
    2. GCP_HOME_SA_KEY: [Use the service account key from terraform output]
    3. GAR_HOME_LOCATION: ${var.region}
    4. REPOSITORY_HOME: e-skimming-labs-home
    
    To get the service account key, run:
    terraform output -raw home_deploy_key
  EOT
}
