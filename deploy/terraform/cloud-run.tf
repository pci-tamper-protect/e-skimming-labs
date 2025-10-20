# Cloud Run Services

# Analytics Service - Shared component for progress tracking
resource "google_cloud_run_v2_service" "analytics_service" {
  name     = "labs-analytics-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.labs_analytics.email
    
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/e-skimming-labs/analytics:latest"
      
      ports {
        container_port = 8080
      }
      
      env {
        name  = "PROJECT_ID"
        value = var.project_id
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
          cpu    = "0.5"
          memory = "256Mi"
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

# SEO Service - Integration with main pcioasis.com
resource "google_cloud_run_v2_service" "seo_service" {
  name     = "labs-seo-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.labs_seo.email
    
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/e-skimming-labs/seo:latest"
      
      ports {
        container_port = 8080
      }
      
      env {
        name  = "PROJECT_ID"
        value = var.project_id
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
        value = var.domain
      }
      
      resources {
        limits = {
          cpu    = "0.5"
          memory = "256Mi"
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
    google_service_account.labs_seo
  ]
}

# Index Service - Main landing page
resource "google_cloud_run_v2_service" "index_service" {
  name     = "labs-index-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.labs_runtime.email
    
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/e-skimming-labs/index:latest"
      
      ports {
        container_port = 8080
      }
      
      env {
        name  = "PROJECT_ID"
        value = var.project_id
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
        name  = "ANALYTICS_SERVICE_URL"
        value = google_cloud_run_v2_service.analytics_service.uri
      }
      
      env {
        name  = "SEO_SERVICE_URL"
        value = google_cloud_run_v2_service.seo_service.uri
      }
      
      resources {
        limits = {
          cpu    = "0.5"
          memory = "256Mi"
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
    google_service_account.labs_runtime
  ]
}

# Allow unauthenticated access to all services
resource "google_cloud_run_v2_service_iam_member" "analytics_public" {
  location = google_cloud_run_v2_service.analytics_service.location
  project  = google_cloud_run_v2_service.analytics_service.project
  name     = google_cloud_run_v2_service.analytics_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "seo_public" {
  location = google_cloud_run_v2_service.seo_service.location
  project  = google_cloud_run_v2_service.seo_service.project
  name     = google_cloud_run_v2_service.seo_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "index_public" {
  location = google_cloud_run_v2_service.index_service.location
  project  = google_cloud_run_v2_service.index_service.project
  name     = google_cloud_run_v2_service.index_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

