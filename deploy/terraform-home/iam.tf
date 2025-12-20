# IAM Configuration for Project Owners
#
# NOTE: The roles/owner role cannot be granted via Terraform or the API.
# It must be granted manually through the GCP Console by an existing project owner.
#
# To grant owner access to staging users, go to:
# GCP Console > IAM & Admin > IAM > Add > Grant "Owner" role
#
# Staging users that should have owner access:
# - user:srichinmai2004@gmail.com
# - user:tmarshiqe@gmail.com
# - user:ayaaslam83@gmail.com
#
# For production, use roles/editor or roles/viewer instead, or grant owner manually.

# Grant Editor role to 2025-interns group on staging projects only
resource "google_project_iam_member" "interns_editor" {
  count = var.environment == "stg" ? 1 : 0

  project = local.home_project_id
  role    = "roles/editor"
  member  = "group:2025-interns@pcioasis.com"
}
