terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.13"
    }
  }

  # Remote state backend - prevents local state files with sensitive data
  # State bucket must be created manually before running terraform init
  # Bucket name is environment-specific - use backend config files:
  #   terraform init -backend-config=backend-stg.conf (for staging)
  #   terraform init -backend-config=backend-prd.conf (for production)
  backend "gcs" {
    # bucket and prefix are set via backend config files
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com",
    "storage.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com"
  ])

  service            = each.value
  disable_on_destroy = false
}

# Create Artifact Registry repository for lab images
resource "google_artifact_registry_repository" "labs_repo" {
  location      = var.region
  repository_id = "e-skimming-labs"
  description   = "E-Skimming Labs container images"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Create Firestore database
resource "google_firestore_database" "labs_db" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # Protect staging from accidental deletion
  # Note: Firestore databases cannot be deleted via Terraform once created
  # Additional protection: use IAM to restrict deletion permissions
  lifecycle {
    prevent_destroy = var.environment == "stg"
  }

  depends_on = [google_project_service.required_apis]
}

# Create Cloud Storage buckets
resource "google_storage_bucket" "labs_data" {
  name          = "${var.project_id}-labs-data"
  location      = var.region
  force_destroy = var.environment == "stg" ? false : true  # Protect staging from deletion

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_storage_bucket" "labs_logs" {
  name          = "${var.project_id}-labs-logs"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Create VPC connector for Cloud Run (if needed for private services)
resource "google_vpc_access_connector" "labs_connector" {
  name          = "labs-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = "default"
  min_instances = 2
  max_instances = 3

  depends_on = [google_project_service.required_apis]
}
