# Service Accounts
resource "google_service_account" "labs_runtime" {
  account_id   = "labs-runtime-sa"
  display_name = "E-Skimming Labs Runtime Service Account"
  description  = "Service account for running Cloud Run lab services"
}

resource "google_service_account" "labs_deploy" {
  account_id   = "labs-deploy-sa"
  display_name = "E-Skimming Labs Deploy Service Account"
  description  = "Service account for GitHub Actions deployment"
}

resource "google_service_account" "labs_analytics" {
  account_id   = "labs-analytics-sa"
  display_name = "E-Skimming Labs Analytics Service Account"
  description  = "Service account for analytics service"
}

resource "google_service_account" "labs_seo" {
  account_id   = "labs-seo-sa"
  display_name = "E-Skimming Labs SEO Service Account"
  description  = "Service account for SEO integration service"
}

# IAM Roles for Runtime Service Account
resource "google_project_iam_member" "labs_runtime_roles" {
  for_each = toset([
    "roles/run.invoker",
    "roles/datastore.user", # Firestore access (roles/firestore.user is not valid at project level)
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/artifactregistry.reader"
  ])

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.labs_runtime.email}"
}

# IAM Roles for Deploy Service Account
# Following principle of least privilege - only permissions needed for deployment
resource "google_project_iam_member" "labs_deploy_roles" {
  for_each = toset([
    "roles/run.developer",           # Deploy and manage Cloud Run services (not full admin)
    "roles/artifactregistry.writer", # Push container images
    "roles/iam.serviceAccountUser",  # Use service accounts for Cloud Run
    "roles/storage.objectViewer",    # Read storage objects during deployment
    "roles/storage.objectCreator"    # Upload deployment artifacts
  ])

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.labs_deploy.email}"
}

# IAM Roles for Analytics Service Account
resource "google_project_iam_member" "labs_analytics_roles" {
  for_each = toset([
    "roles/datastore.user", # Firestore access (roles/firestore.user is not valid at project level)
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ])

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.labs_analytics.email}"
}

# IAM Roles for SEO Service Account
resource "google_project_iam_member" "labs_seo_roles" {
  for_each = toset([
    "roles/datastore.user", # Firestore access (roles/firestore.user is not valid at project level)
    "roles/storage.objectViewer",
    "roles/logging.logWriter"
  ])

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.labs_seo.email}"
}

# Create service account keys for GitHub Actions
resource "google_service_account_key" "labs_deploy_key" {
  service_account_id = google_service_account.labs_deploy.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Output the service account key for GitHub Secrets
output "labs_deploy_key" {
  description = "Service account key for GitHub Actions deployment"
  value       = base64decode(google_service_account_key.labs_deploy_key.private_key)
  sensitive   = true
}

