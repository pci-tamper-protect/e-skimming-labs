# Cloud Run Services for Home Page
# Note: These services will be deployed after Docker images are built and pushed

# SEO Service - Integration with main pcioasis.com
resource "google_cloud_run_v2_service" "home_seo_service" {
  count    = var.deploy_services ? 1 : 0
  name     = "home-seo-${var.environment}"
  location = var.region
  project  = local.project_id

  template {
    service_account = google_service_account.home_seo.email

    containers {
      image = "${var.region}-docker.pkg.dev/${local.project_id}/e-skimming-labs-home/seo:latest"

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
        name  = "MAIN_DOMAIN"
        value = var.main_domain
      }

      env {
        name  = "LABS_DOMAIN"
        value = var.labs_domain
      }

      env {
        name  = "LABS_PROJECT_ID"
        value = local.labs_project_id
      }

      resources {
        limits = {
          cpu    = "1"
          memory = var.memory_limit
        }
      }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }

  depends_on = [
    google_artifact_registry_repository.home_repo,
    google_service_account.home_seo
  ]
}

# Index Service - Main landing page
resource "google_cloud_run_v2_service" "home_index_service" {
  count    = var.deploy_services ? 1 : 0
  name     = "home-index-${var.environment}"
  location = var.region
  project  = local.project_id

  template {
    service_account = google_service_account.home_runtime.email

    containers {
      image = "${var.region}-docker.pkg.dev/${local.project_id}/e-skimming-labs-home/index:latest"

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
        name  = "DOMAIN"
        value = var.domain
      }

      env {
        name  = "LABS_DOMAIN"
        value = var.labs_domain
      }

      env {
        name  = "MAIN_DOMAIN"
        value = var.main_domain
      }

      env {
        name  = "LABS_PROJECT_ID"
        value = local.labs_project_id
      }

      env {
        name  = "SEO_SERVICE_URL"
        value = var.deploy_services ? google_cloud_run_v2_service.home_seo_service[0].uri : ""
      }

      resources {
        limits = {
          cpu    = "1"
          memory = var.memory_limit
        }
      }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }

  depends_on = [
    google_artifact_registry_repository.home_repo,
    google_service_account.home_runtime
  ]
}

# IAM access control - environment-specific
# Production: Public access (allUsers)
# Staging: Restricted to developer groups (configured in iap.tf)

resource "google_cloud_run_v2_service_iam_member" "home_seo_public" {
  count    = var.deploy_services && var.environment == "prd" ? 1 : 0
  location = google_cloud_run_v2_service.home_seo_service[0].location
  project  = google_cloud_run_v2_service.home_seo_service[0].project
  name     = google_cloud_run_v2_service.home_seo_service[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "home_index_public" {
  count    = var.deploy_services && var.environment == "prd" ? 1 : 0
  location = google_cloud_run_v2_service.home_index_service[0].location
  project  = google_cloud_run_v2_service.home_index_service[0].project
  name     = google_cloud_run_v2_service.home_index_service[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Note: For staging (stg), access is restricted via IAM group bindings in iap.tf
# Groups: 2025-interns@pcioasis.com, core-eng@pcioasis.com