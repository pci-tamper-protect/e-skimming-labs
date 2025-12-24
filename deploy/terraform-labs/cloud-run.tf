# Cloud Run Services for Individual Labs
# Note: These services will be deployed after Docker images are built and pushed

# Analytics Service - Shared component for progress tracking
# Note: Service is deployed by GitHub Actions workflow, Terraform only manages IAM
# Keep in state to prevent destruction, but ignore all changes (managed by GitHub Actions)
resource "google_cloud_run_v2_service" "analytics_service" {
  count    = 1  # Always keep in state to prevent destruction
  name     = "labs-analytics-${var.environment}"
  location = var.region
  project  = local.labs_project_id

  # Protect staging from accidental deletion
  deletion_protection = var.environment == "stg" ? true : false

  # Let GitHub Actions workflow manage the service configuration
  # Terraform only needs the service to exist for IAM bindings
  # Ignore all changes since GitHub Actions manages the actual deployment
  lifecycle {
    ignore_changes = all  # Ignore all changes - service is fully managed by GitHub Actions
  }

  template {
    service_account = google_service_account.labs_analytics.email

    containers {
      image = "${var.region}-docker.pkg.dev/${local.labs_project_id}/e-skimming-labs/analytics:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "LABS_PROJECT_ID"
        value = local.labs_project_id
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
# IAM binding persists regardless of deploy_services flag
resource "google_cloud_run_v2_service_iam_member" "analytics_runtime_access" {
  location = google_cloud_run_v2_service.analytics_service[0].location
  project  = google_cloud_run_v2_service.analytics_service[0].project
  name     = google_cloud_run_v2_service.analytics_service[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.labs_runtime.email}"
}

# Note: SEO and Index service IAM policies are in labs-home-prd project
