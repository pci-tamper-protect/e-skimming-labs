# Service Accounts for Home Page Project

resource "google_service_account" "home_runtime" {
  account_id   = "home-runtime-sa"
  display_name = "E-Skimming Labs Home Runtime Service Account"
  description  = "Service account for running Cloud Run home page services"
}

resource "google_service_account" "home_deploy" {
  account_id   = "home-deploy-sa"
  display_name = "E-Skimming Labs Home Deploy Service Account"
  description  = "Service account for GitHub Actions home page deployment"
}

resource "google_service_account" "home_seo" {
  account_id   = "home-seo-sa"
  display_name = "E-Skimming Labs Home SEO Service Account"
  description  = "Service account for SEO integration service"
}

# IAM Roles for Home Runtime Service Account
resource "google_project_iam_member" "home_runtime_roles" {
  for_each = toset([
    "roles/run.invoker",
    "roles/datastore.user",
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/artifactregistry.reader"
  ])

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.home_runtime.email}"
}

# IAM Roles for Home Deploy Service Account
# Following principle of least privilege - only permissions needed for deployment
resource "google_project_iam_member" "home_deploy_roles" {
  for_each = toset([
    "roles/run.developer",           # Deploy and manage Cloud Run services (not full admin)
    "roles/artifactregistry.writer", # Push container images
    "roles/iam.serviceAccountUser",  # Use service accounts for Cloud Run
    "roles/storage.objectViewer",    # Read storage objects during deployment
    "roles/storage.objectCreator"    # Upload deployment artifacts
  ])

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.home_deploy.email}"
}

# IAM Roles for Home SEO Service Account
resource "google_project_iam_member" "home_seo_roles" {
  for_each = toset([
    "roles/datastore.user",
    "roles/storage.objectViewer",
    "roles/logging.logWriter"
  ])

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.home_seo.email}"
}

# Create service account key for GitHub Actions
resource "google_service_account_key" "home_deploy_key" {
  service_account_id = google_service_account.home_deploy.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Output the service account key for GitHub Secrets
output "home_deploy_key" {
  description = "Service account key for GitHub Actions home page deployment"
  value       = base64decode(google_service_account_key.home_deploy_key.private_key)
  sensitive   = true
}
