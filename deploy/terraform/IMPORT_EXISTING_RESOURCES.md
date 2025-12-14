# Importing Existing Resources

## Prerequisites

Before running any Terraform commands, authenticate with Google Cloud:

```bash
gcloud auth application-default login
```

**Note**: This guide is primarily for production deployments. Staging projects (`labs-stg`, `labs-home-stg`) should be empty and Terraform will create all resources fresh.

If you're deploying to production projects that already have some resources, you may need to import them into Terraform state.

## Firestore Database

If the Firestore database already exists:

```bash
cd deploy/terraform

# Import the existing database
terraform import google_firestore_database.labs_db projects/labs-stg/databases/(default)
```

For terraform-home:
```bash
cd deploy/terraform-home
terraform import google_firestore_database.home_db projects/labs-home-stg/databases/(default)
```

For terraform-labs:
```bash
cd deploy/terraform-labs
terraform import google_firestore_database.labs_db projects/labs-stg/databases/(default)
```

## Other Resources

If other resources already exist (service accounts, buckets, etc.), you can import them similarly:

```bash
# Service account
terraform import google_service_account.labs_runtime projects/labs-stg/serviceAccounts/labs-runtime-sa@labs-stg.iam.gserviceaccount.com

# Storage bucket
terraform import google_storage_bucket.labs_data labs-stg-labs-data

# Artifact Registry repository
terraform import google_artifact_registry_repository.labs_repo projects/labs-stg/locations/us-central1/repositories/e-skimming-labs
```

## Check What Exists

Before importing, check what resources already exist:

```bash
# List Firestore databases
gcloud firestore databases list --project=labs-stg

# List service accounts
gcloud iam service-accounts list --project=labs-stg

# List storage buckets
gsutil ls -p labs-stg

# List Artifact Registry repositories
gcloud artifacts repositories list --location=us-central1 --project=labs-stg
```

