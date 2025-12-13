# Cloud Run Services for Individual Labs
# Note: These services will be deployed after Docker images are built and pushed

# Analytics Service - Shared component for progress tracking
resource "google_cloud_run_v2_service" "analytics_service" {
  count    = var.deploy_services ? 1 : 0
  name     = "labs-analytics-${var.environment}"
  location = var.region
  project  = local.project_id

  # Protect staging from accidental deletion
  deletion_protection = var.environment == "stg" ? true : false

  template {
    service_account = google_service_account.labs_analytics.email

    containers {
      image = "${var.region}-docker.pkg.dev/${local.project_id}/e-skimming-labs/analytics:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "PROJECT_ID"
        value = local.project_id
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "FIRESTORE_DATABASE"
        value = google_firestore_database.labs_db.name
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }

  depends_on = [
    google_artifact_registry_repository.labs_repo,
    google_service_account.labs_analytics
  ]
}

# Note: SEO Service and Index Service are now deployed in labs-home-prd project

# Analytics service - Protected backend, only callable by lab services
resource "google_cloud_run_v2_service_iam_member" "analytics_runtime_access" {
  count    = var.deploy_services ? 1 : 0
  location = google_cloud_run_v2_service.analytics_service[0].location
  project  = google_cloud_run_v2_service.analytics_service[0].project
  name     = google_cloud_run_v2_service.analytics_service[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.labs_runtime.email}"
}

# Note: SEO and Index service IAM policies are in labs-home-prd project
