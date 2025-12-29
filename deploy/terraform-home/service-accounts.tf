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

resource "google_service_account" "fbase_adm_sdk_runtime" {
  account_id   = "fbase-adm-sdk-runtime"
  display_name = "Firebase Admin SDK Runtime Service Account"
  description  = "Service account for Firebase Admin SDK operations (token validation)"
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

# IAM Roles for Firebase Admin SDK Runtime Service Account
# Basic runtime permissions in home project
resource "google_project_iam_member" "fbase_adm_sdk_runtime_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/iam.serviceAccountUser",  # Allow service account to act as itself
    "roles/secretmanager.secretAccessor"  # Access Secret Manager secrets (e.g., DOTENVX_KEY_STG)
  ])

  project = local.home_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.fbase_adm_sdk_runtime.email}"
}

# Cross-project IAM: Grant Firebase Admin SDK permissions in Firebase project
# This allows the service account to validate Firebase ID tokens
resource "google_project_iam_member" "fbase_adm_sdk_runtime_firebase_admin" {
  project = local.firebase_project_id
  role    = "roles/firebase.admin"
  member  = "serviceAccount:${google_service_account.fbase_adm_sdk_runtime.email}"
}

# Allow deploy service account to use Firebase Admin SDK runtime service account
# This is required for GitHub Actions to deploy Cloud Run services with this service account
resource "google_service_account_iam_member" "deploy_can_use_fbase_runtime" {
  service_account_id = google_service_account.fbase_adm_sdk_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.home_deploy.email}"
}

# NOTE: Service account keys are NOT managed by Terraform
# Keys are created using gcloud and managed via scripts in pcioasis-ops/secrets
# This follows the principle: Terraform manages infrastructure (SAs, IAM), gcloud manages credentials (keys)
#
# To create keys:
#   - For deploy SA: Use gcloud or create-service-account-key-and-update-env.sh
#   - For Firebase Admin SDK runtime SA: Use create-or-rotate-service-account-key.sh
