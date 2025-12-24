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

# Traefik Cloud Run Service
resource "google_cloud_run_v2_service" "traefik" {
  count    = 1
  name     = "traefik-${var.environment}"
  location = var.region
  project  = local.labs_project_id

  # Protect staging from accidental deletion
  deletion_protection = var.environment == "stg" ? true : false

  template {
    service_account = google_service_account.traefik.email

    # Scale configuration
    scaling {
      min_instance_count = var.environment == "prd" ? 1 : 0  # Keep 1 instance warm in production
      max_instance_count = var.environment == "prd" ? 10 : 3
    }

    containers {
      # Image will be built and pushed by GitHub Actions
      image = "${var.region}-docker.pkg.dev/${local.labs_project_id}/e-skimming-labs/traefik:latest"

      ports {
        name           = "http1"
        container_port = 8080
      }

      # Environment variables for backend service URLs
      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "DOMAIN"
        value = var.environment == "prd" ? "labs.pcioasis.com" : "labs.stg.pcioasis.com"
      }

      # Home services (from labs-home project)
      env {
        name  = "HOME_INDEX_URL"
        value = "https://home-index-${var.environment}-${data.google_project.home_project.number}.a.run.app"
      }

      env {
        name  = "SEO_URL"
        value = "https://home-seo-${var.environment}-${data.google_project.home_project.number}.a.run.app"
      }

      # Analytics service (from labs project)
      env {
        name  = "ANALYTICS_URL"
        value = google_cloud_run_v2_service.analytics_service[0].uri
      }

      # Lab service URLs (to be deployed separately)
      # These will be populated by the lab deployment workflows
      env {
        name  = "LAB1_URL"
        value = "https://lab1-${var.environment}-${data.google_project.labs_project.number}.a.run.app"
      }

      env {
        name  = "LAB1_C2_URL"
        value = "https://lab1-c2-${var.environment}-${data.google_project.labs_project.number}.a.run.app"
      }

      env {
        name  = "LAB2_URL"
        value = "https://lab2-${var.environment}-${data.google_project.labs_project.number}.a.run.app"
      }

      env {
        name  = "LAB2_C2_URL"
        value = "https://lab2-c2-${var.environment}-${data.google_project.labs_project.number}.a.run.app"
      }

      env {
        name  = "LAB3_URL"
        value = "https://lab3-${var.environment}-${data.google_project.labs_project.number}.a.run.app"
      }

      env {
        name  = "LAB3_EXTENSION_URL"
        value = "https://lab3-extension-${var.environment}-${data.google_project.labs_project.number}.a.run.app"
      }

      # Resource limits
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true  # Scale to zero when idle in staging
      }

      # Startup probe
      startup_probe {
        http_get {
          path = "/ping"
        }
        initial_delay_seconds = 5
        timeout_seconds       = 3
        period_seconds        = 3
        failure_threshold     = 5
      }

      # Liveness probe
      liveness_probe {
        http_get {
          path = "/ping"
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }
    }

    # VPC connector for accessing internal services (if needed)
    # vpc_access {
    #   connector = var.vpc_connector
    #   egress    = "PRIVATE_RANGES_ONLY"
    # }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_artifact_registry_repository.labs_repo,
    google_service_account.traefik,
    google_project_iam_member.traefik_invoker
  ]

  # Ignore changes made by GitHub Actions
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      template[0].annotations,
      client,
      client_version
    ]
  }
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
  location = google_cloud_run_v2_service.traefik[0].location
  project  = google_cloud_run_v2_service.traefik[0].project
  name     = google_cloud_run_v2_service.traefik[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# For staging, grant access to developer groups (configured in iap.tf)
# Note: The actual IAM bindings are in iap.tf for staging environment

# Domain mapping for Traefik service
resource "google_cloud_run_domain_mapping" "traefik_domain" {
  count = 1

  name     = var.environment == "prd" ? "labs.pcioasis.com" : "labs.stg.pcioasis.com"
  location = var.region
  project  = local.labs_project_id

  metadata {
    namespace = local.labs_project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.traefik[0].name
  }

  # Ignore changes to allow manual management
  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    google_cloud_run_v2_service.traefik
  ]
}

# Output Traefik service URL
output "traefik_url" {
  description = "URL of the Traefik reverse proxy service"
  value       = try(google_cloud_run_v2_service.traefik[0].uri, "not deployed")
}

output "traefik_domain" {
  description = "Custom domain for Traefik service"
  value       = var.environment == "prd" ? "https://labs.pcioasis.com" : "https://labs.stg.pcioasis.com"
}

output "traefik_service_account" {
  description = "Email of the Traefik service account"
  value       = google_service_account.traefik.email
}
