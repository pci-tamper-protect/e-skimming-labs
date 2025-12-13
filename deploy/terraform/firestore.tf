# Firestore Collections and Security Rules
# Note: The main Firestore database is defined in main.tf

# Firestore indexes for better query performance
# These depend on the database existing first
resource "google_firestore_index" "user_progress_index" {
  project    = local.project_id
  database   = "(default)"
  collection = "user_progress"

  depends_on = [google_firestore_database.labs_db]

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

  fields {
    field_path = "__name__"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "analytics_index" {
  project    = local.project_id
  database   = "(default)"
  collection = "analytics"

  depends_on = [google_firestore_database.labs_db]

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

  fields {
    field_path = "__name__"
    order      = "ASCENDING"
  }
}

resource "google_firestore_index" "seo_data_index" {
  project    = local.project_id
  database   = "(default)"
  collection = "seo_data"

  depends_on = [google_firestore_database.labs_db]

  fields {
    field_path = "lab_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "last_updated"
    order      = "DESCENDING"
  }

  fields {
    field_path = "__name__"
    order      = "DESCENDING"
  }
}

