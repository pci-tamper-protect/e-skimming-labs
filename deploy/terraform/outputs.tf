# Outputs

output "project_id" {
  description = "The GCP project ID"
  value       = local.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "artifact_registry_repository" {
  description = "The Artifact Registry repository URL"
  value       = google_artifact_registry_repository.labs_repo.name
}

output "firestore_database" {
  description = "The Firestore database name"
  value       = google_firestore_database.labs_db.name
}

output "storage_bucket_data" {
  description = "The Cloud Storage bucket for lab data"
  value       = google_storage_bucket.labs_data.name
}

output "storage_bucket_logs" {
  description = "The Cloud Storage bucket for logs"
  value       = google_storage_bucket.labs_logs.name
}

output "analytics_service_url" {
  description = "The Analytics service URL"
  value       = google_cloud_run_v2_service.analytics_service.uri
}

# Note: SEO and Index services are deployed in labs-home-stg/labs-home-prd project
# See terraform-home/outputs.tf for their URLs

output "labs_runtime_service_account" {
  description = "The runtime service account email"
  value       = google_service_account.labs_runtime.email
}

output "labs_deploy_service_account" {
  description = "The deploy service account email"
  value       = google_service_account.labs_deploy.email
}

output "labs_analytics_service_account" {
  description = "The analytics service account email"
  value       = google_service_account.labs_analytics.email
}

output "labs_seo_service_account" {
  description = "The SEO service account email"
  value       = google_service_account.labs_seo.email
}

# GitHub Secrets (to be added manually)
output "github_secrets_instructions" {
  description = "Instructions for setting up GitHub secrets"
  value       = <<-EOT
    Add the following secrets to your GitHub repository:
    
    1. GCP_PROJECT_ID: ${local.project_id}
    2. GCP_SA_KEY: [Use the service account key from terraform output]
    3. GAR_LOCATION: ${var.region}
    4. REPOSITORY: e-skimming-labs
    
    To get the service account key, run:
    terraform output -raw labs_deploy_key
  EOT
}

