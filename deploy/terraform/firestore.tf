# Firestore Collections and Security Rules

# Firestore security rules
resource "google_firestore_database" "labs_db_rules" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # Security rules for the database
  depends_on = [google_firestore_database.labs_db]
}

# Firestore indexes for better query performance
resource "google_firestore_index" "user_progress_index" {
  project = var.project_id
  database = "(default)"
  collection = "user_progress"

  fields {
    field_path = "user_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "lab_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "completed_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "analytics_index" {
  project = var.project_id
  database = "(default)"
  collection = "analytics"

  fields {
    field_path = "event_type"
    order      = "ASCENDING"
  }

  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }

  fields {
    field_path = "lab_id"
    order      = "ASCENDING"
  }
}

resource "google_firestore_index" "seo_data_index" {
  project = var.project_id
  database = "(default)"
  collection = "seo_data"

  fields {
    field_path = "lab_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "last_updated"
    order      = "DESCENDING"
  }
}

