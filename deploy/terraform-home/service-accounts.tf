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

  project = local.home_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.home_runtime.email}"
}

# IAM Roles for Home Deploy Service Account
# Following principle of least privilege - only permissions needed for deployment
resource "google_project_iam_member" "home_deploy_roles" {
  for_each = toset([
    "roles/run.admin",               # Deploy, manage Cloud Run services, and set IAM policies
    "roles/artifactregistry.writer", # Push container images
    "roles/iam.serviceAccountUser",  # Use service accounts for Cloud Run
    "roles/storage.objectViewer",    # Read storage objects during deployment
    "roles/storage.objectCreator"    # Upload deployment artifacts
  ])

  project = local.home_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.home_deploy.email}"
}

# Repository-level IAM binding for Artifact Registry (explicit permissions)
# This ensures the service account can upload artifacts to the repository
resource "google_artifact_registry_repository_iam_member" "home_deploy_artifact_registry_writer" {
  location   = var.region
  repository = google_artifact_registry_repository.home_repo.repository_id
  project    = local.home_project_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.home_deploy.email}"

  depends_on = [
    google_artifact_registry_repository.home_repo,
    google_service_account.home_deploy
  ]
}

# Grant Artifact Registry admin access to core-eng and 2025-interns groups (staging only)
resource "google_artifact_registry_repository_iam_member" "core_eng_artifact_registry_admin" {
  count = var.environment == "stg" ? 1 : 0

  location   = var.region
  repository = google_artifact_registry_repository.home_repo.repository_id
  project    = local.home_project_id
  role       = "roles/artifactregistry.admin"
  member     = "group:core-eng@pcioasis.com"

  depends_on = [google_artifact_registry_repository.home_repo]
}

resource "google_artifact_registry_repository_iam_member" "interns_artifact_registry_admin" {
  count = var.environment == "stg" ? 1 : 0

  location   = var.region
  repository = google_artifact_registry_repository.home_repo.repository_id
  project    = local.home_project_id
  role       = "roles/artifactregistry.admin"
  member     = "group:2025-interns@pcioasis.com"

  depends_on = [google_artifact_registry_repository.home_repo]
}

# IAM Roles for Home SEO Service Account
resource "google_project_iam_member" "home_seo_roles" {
  for_each = toset([
    "roles/datastore.user",
    "roles/storage.objectViewer",
    "roles/logging.logWriter"
  ])

  project = local.home_project_id
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
