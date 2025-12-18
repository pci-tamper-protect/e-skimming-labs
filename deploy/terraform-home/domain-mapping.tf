# Domain Mapping for Home Index Service
# Note: Domain mappings take 2-10 hours to provision, so we use lifecycle ignore_changes
# to allow manual creation while still tracking it in Terraform

# Domain mapping for staging - keep in state to prevent destruction
# Note: Domain mappings are managed separately, Terraform just tracks them
resource "google_cloud_run_domain_mapping" "home_index_stg" {
  count = var.environment == "stg" ? 1 : 0
  
  name     = "labs.stg.pcioasis.com"
  location = var.region
  project  = local.home_project_id

  metadata {
    namespace = local.home_project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.home_index_service[0].name
  }

  # Ignore all changes to allow manual management
  # Domain mappings are slow to provision (2-10 hours) and DNS is managed separately
  lifecycle {
    ignore_changes = all
    create_before_destroy = false
  }

  depends_on = [
    google_cloud_run_v2_service.home_index_service
  ]
}

# Production domain mapping - keep in state to prevent destruction
# Note: Domain mappings are managed separately, Terraform just tracks them
resource "google_cloud_run_domain_mapping" "home_index_prd" {
  count = var.environment == "prd" ? 1 : 0
  
  name     = "labs.pcioasis.com"
  location = var.region
  project  = local.home_project_id

  metadata {
    namespace = local.home_project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.home_index_service[0].name
  }

  lifecycle {
    ignore_changes = all
    create_before_destroy = false
  }

  depends_on = [
    google_cloud_run_v2_service.home_index_service
  ]
}

