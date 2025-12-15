# E-Skimming Labs Deployment Setup

This directory contains scripts for setting up the deployment infrastructure for e-skimming-labs.

## Prerequisites

Before running any deployment scripts or Terraform commands, authenticate with Google Cloud:

```bash
gcloud auth application-default login
```

This will open a browser for you to authenticate with your Google account. After authentication, Terraform and other tools will use these credentials.

## Setup Sequence

Run these scripts in order for initial infrastructure setup:

### 1. Create Service Accounts

```bash
./deploy/create-service-accounts.sh
```

This script:
- Creates `github-actions@labs-prd.iam.gserviceaccount.com` service account
- Creates `github-actions@labs-home-prd.iam.gserviceaccount.com` service account
- Grants necessary IAM roles:
  - `roles/run.admin` - Deploy to Cloud Run
  - `roles/artifactregistry.writer` - Push Docker images
  - `roles/iam.serviceAccountUser` - Use service accounts
- Grants cross-project access to read from `pcioasis-operations/containers`
- Creates and downloads service account keys

**Output**: `deploy/labs-sa-key.json` and `deploy/home-sa-key.json`

### 2. Add Service Account Keys to GitHub Secrets

```bash
# Add labs key
gh secret set GCP_LABS_SA_KEY --body "$(cat deploy/labs-sa-key.json | base64)" --repo pci-tamper-protect/e-skimming-labs

# Add home key
gh secret set GCP_HOME_SA_KEY --body "$(cat deploy/home-sa-key.json | base64)" --repo pci-tamper-protect/e-skimming-labs
```

### 3. Create Artifact Registry Repositories

```bash
./deploy/setup-artifact-registry.sh
```

This script:
- Creates `labs` repository in `labs-prd` project
- Creates `home` repository in `labs-home-prd` project
- Grants necessary permissions to service accounts:
  - `roles/artifactregistry.writer` - Push images
  - `roles/artifactregistry.reader` - Pull images
- Grants read access to golden base images from `pcioasis-operations`

### 4. Clean Up Key Files

```bash
# Remove keys after adding to GitHub secrets
rm deploy/*-sa-key.json
```

## Verify Setup

After running the setup scripts, verify:

1. **Service Accounts exist**:
   ```bash
   gcloud iam service-accounts describe github-actions@labs-prd.iam.gserviceaccount.com --project=labs-prd
   gcloud iam service-accounts describe github-actions@labs-home-prd.iam.gserviceaccount.com --project=labs-home-prd
   ```

2. **GitHub Secrets exist**:
   ```bash
   gh secret list --repo pci-tamper-protect/e-skimming-labs
   ```

3. **Artifact Registry repositories exist**:
   ```bash
   gcloud artifacts repositories list --location=us-central1 --project=labs-prd
   gcloud artifacts repositories list --location=us-central1 --project=labs-home-prd
   ```

4. **Permissions are granted**:
   ```bash
   gcloud artifacts repositories get-iam-policy labs --location=us-central1 --project=labs-prd
   gcloud artifacts repositories get-iam-policy home --location=us-central1 --project=labs-home-prd
   ```

## Troubleshooting

### Permission denied errors

If you see `Permission "artifactregistry.repositories.downloadArtifacts" denied`:
- Ensure the service accounts have `roles/artifactregistry.reader` on the repositories
- Check that cross-project access to `pcioasis-operations` was granted
- Verify service account keys are correctly added to GitHub secrets

### Repository not found errors

If you see `Repository "***" not found`:
- Ensure you ran `./deploy/setup-artifact-registry.sh`
- Verify the repositories were created successfully
- Check the repository names match those in the GitHub workflow

### Service account key errors

If GitHub Actions can't authenticate:
- Verify the keys were added to GitHub secrets with the correct names
- Check that the keys are base64 encoded correctly
- Ensure the service account key files were deleted after adding to GitHub
