# GCP Deployment Scripts

This directory contains Google Cloud Platform deployment scripts for the E-Skimming Labs project.

## Scripts

### storage.sh

Creates Google Cloud Storage buckets for the C2 server's smart aggregation storage adapter.

**Usage:**
```bash
./storage.sh <prd|stg>
```

**Examples:**
```bash
# Create production storage bucket
./storage.sh prd

# Create staging storage bucket  
./storage.sh stg
```

**What it does:**
- Creates environment-specific GCS bucket: `e-skimming-labs-c2-data-{env}`
- Sets up lifecycle policy (90-day auto-deletion)
- Enables uniform bucket-level access for security
- Configures IAM permissions for GitHub Actions service account
- Adds `C2_STORAGE_BUCKET` environment variable to `.env.{env}`

**Requirements:**
- `gcloud` CLI installed and authenticated
- Access to the appropriate GCP project (`labs-home-prd` or `labs-home-stg`)
- Existing GitHub Actions service account in the target project

**Bucket Configuration:**
- **Location:** us-central1
- **Storage Class:** Standard
- **Access:** Uniform bucket-level access
- **Lifecycle:** Delete objects after 90 days
- **Permissions:** GitHub Actions service account has Storage Object Admin access

The created bucket will be automatically used by the C2 server when deployed to Cloud Run with smart aggregation enabled.
