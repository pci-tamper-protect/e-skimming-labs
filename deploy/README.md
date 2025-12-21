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

## Dotenvx Setup (Encrypted Environment Files)

This project uses dotenvx to encrypt environment files. The encrypted `.env.stg` and `.env.prd` files are stored in the repository, and the private keys (`.env.keys.stg` and `.env.keys.prd`) are stored in Google Cloud Secret Manager and mounted at runtime in Cloud Run.

### Uploading Dotenvx Keys to Secret Manager

Upload the private keys to Secret Manager:

```bash
# For staging (labs-stg project)
./deploy/upload-dotenvx-key.sh stg labs-stg

# For production (labs-prd project)
./deploy/upload-dotenvx-key.sh prd labs-prd
```

This script will:
1. Check if the `.env.keys.<env>` file exists
2. Create or update the secret `DOTENVX_KEY_<ENV>` in Secret Manager
3. Provide instructions for granting Cloud Run service account access

### Granting Cloud Run Service Account Access

After uploading the secrets, grant the Cloud Run service accounts access:

```bash
# For staging - labs services
gcloud secrets add-iam-policy-binding DOTENVX_KEY_STG \
  --project=labs-stg \
  --member='serviceAccount:labs-runtime-sa@labs-stg.iam.gserviceaccount.com' \
  --role='roles/secretmanager.secretAccessor'

# For staging - home services
gcloud secrets add-iam-policy-binding DOTENVX_KEY_STG \
  --project=labs-home-stg \
  --member='serviceAccount:home-runtime-sa@labs-home-stg.iam.gserviceaccount.com' \
  --role='roles/secretmanager.secretAccessor'

# For production - labs services
gcloud secrets add-iam-policy-binding DOTENVX_KEY_PRD \
  --project=labs-prd \
  --member='serviceAccount:labs-runtime-sa@labs-prd.iam.gserviceaccount.com' \
  --role='roles/secretmanager.secretAccessor'

# For production - home services
gcloud secrets add-iam-policy-binding DOTENVX_KEY_PRD \
  --project=labs-home-prd \
  --member='serviceAccount:home-runtime-sa@labs-home-prd.iam.gserviceaccount.com' \
  --role='roles/secretmanager.secretAccessor'
```

### How It Works

**Runtime (Cloud Run):**
- The dotenvx private key is mounted at `/etc/secrets/dotenvx-key` in all Cloud Run services
- The encrypted `.env.stg` or `.env.prd` files are already in the container image (from the repo)
- At container startup, the application should:
  1. Symlink `/etc/secrets/dotenvx-key` → `.env.keys` (or `.env.keys.stg`/`.env.keys.prd`)
  2. Symlink `.env.stg` or `.env.prd` → `.env` (based on environment)
  3. dotenvx will automatically and transparently decrypt when it sees both the encrypted file and matching key file

**How dotenvx Works:**
- When dotenvx sees both `.env.<env>` (encrypted) and `.env.keys.<env>` (key) files, it automatically decrypts on-the-fly
- No manual `dotenvx decrypt` command needed - it's transparent
- Tools that read `.env` will get decrypted values automatically
- The encrypted `.env.<env>` file stays encrypted in the repo (safe to commit)

### Secret Mounting in GitHub Actions

The GitHub Actions workflow (`.github/workflows/deploy_labs.yml`) automatically mounts the appropriate secret for each environment:
- **Staging services**: `--update-secrets="/etc/secrets/dotenvx-key:DOTENVX_KEY_STG:latest"`
- **Production services**: `--update-secrets="/etc/secrets/dotenvx-key:DOTENVX_KEY_PRD:latest"`

All Cloud Run deployments (home-seo, home-index, labs-analytics, lab-*-*, labs-index) have the secret mounted automatically.

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
