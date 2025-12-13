# Terraform Authentication Setup

## Problem
Terraform is getting OAuth2 authentication errors when accessing the GCS backend:
```
Error: Failed to get existing workspaces: querying Cloud Storage failed: ... oauth2: cannot fetch token: 400 Bad Request
```

## Solutions

### Option 1: Re-authenticate Application Default Credentials (Recommended)

If you're using user credentials:

```bash
# Re-authenticate with application default credentials
gcloud auth application-default login

# Verify it works
gcloud auth application-default print-access-token
```

### Option 2: Use Service Account Key File

If you have a service account key file:

```bash
# Set the credentials file
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"

# Verify it works
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
```

### Option 3: Configure Terraform Provider Explicitly

You can also configure the provider in `main.tf` to use explicit credentials:

```hcl
provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.credentials_file)  # Add this if using service account key
}
```

Then pass the credentials file path as a variable.

## Verify Authentication

After setting up credentials, verify Terraform can access GCS:

```bash
cd deploy/terraform
terraform init
```

If successful, you should see:
```
Initializing the backend...
Successfully configured the backend "gcs"!
```

## Notes

- The GCS backend bucket `e-skimming-labs-terraform-state-{prd|stg}` must exist and be accessible (environment-specific)
- Your credentials need `roles/storage.objectAdmin` on the state bucket
- For production, prefer service account keys over user credentials

