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

## Firebase SSO Setup

This project uses Firebase Authentication with Single Sign-On (SSO) between `www.pcioasis.com` and `labs.pcioasis.com`. See `docs/FIREBASE_SSO_DESIGN.md` for the complete architecture.

### Create Restricted Firebase Service Account

Create a restricted service account for labs that can set custom claims but has no Firestore access:

```bash
# For staging
./deploy/secrets/create-firebase-service-account.sh stg

# For production
./deploy/secrets/create-firebase-service-account.sh prd
```

This script:
- Creates custom IAM role `labs.firebase.authValidator` with minimal permissions:
  - `firebaseauth.users.update` - Set custom claims
  - `firebaseauth.users.get` - Read user information
  - **No Firestore permissions** (enforces least privilege)
- Creates service account `labs-auth-validator@<firebase-project>.iam.gserviceaccount.com`
- Grants the custom role to the service account
- Creates and downloads service account key to `deploy/labs-auth-validator-<env>-key.json`

**Next Steps:**
1. Add the service account key JSON to `.env.<env>` (project root) as `FIREBASE_SERVICE_ACCOUNT_KEY`
   
   **Easy way (recommended):** Use the helper script from `pcioasis-ops/secrets`:
   ```bash
   # Copy key to clipboard (ready to paste into .env file)
   ../../pcioasis-ops/secrets/copy-service-account-to-env.sh deploy/labs-auth-validator-<env>-key.json
   
   # Or directly append to .env file
   ../../pcioasis-ops/secrets/copy-service-account-to-env.sh deploy/labs-auth-validator-<env>-key.json .env.<env>
   ```
   
   **Note:** 
   - Scripts are located in `pcioasis-ops/secrets/` (shared across projects)
   - Requires `jq` (install with `brew install jq`)
   - The `dotenvx-converter.py` script will automatically add keys to .env files and clean up key files
   
   **Manual way:** The key JSON needs to be on a single line with escaped newlines and quotes:
   ```bash
   FIREBASE_SERVICE_ACCOUNT_KEY="{\"type\":\"service_account\",\"project_id\":\"...\",\"private_key\":\"-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n\"}"
   ```

2. Encrypt the `.env` file: `dotenvx encrypt .env.<env>`
3. Update Firestore security rules to check custom claims (see `docs/FIREBASE_SSO_DESIGN.md`)
4. Deploy Cloud Function or backend service to set custom claims on sign-up

### Validate Firebase API Key

To verify that `FIREBASE_API_KEY` in your `.env.<env>` file is valid and working:

```bash
# Validate staging API key
./deploy/secrets/validate-firebase-api-key.sh stg

# Validate production API key
./deploy/secrets/validate-firebase-api-key.sh prd
```

This script:
- Automatically decrypts `.env.<env>` if encrypted (using dotenvx)
- Extracts `FIREBASE_API_KEY` and `FIREBASE_PROJECT_ID`
- Makes a test API call to Firebase's Identity Toolkit API
- Reports whether the key is valid and working

**What it checks:**
- ✅ API key is present in the `.env` file
- ✅ API key is valid (not expired or revoked)
- ✅ API key matches the specified Firebase project
- ✅ Identity Toolkit API is enabled for the project

**Common errors:**
- `HTTP 400`: Invalid API key format
- `HTTP 403`: API key restrictions or Identity Toolkit API not enabled
- `HTTP 404`: Project ID doesn't exist or you don't have access

### Set Custom Claims for Users

To manually set custom claims for a user (for testing):

```bash
# Set claims for a user in production
./deploy/set-firebase-custom-claims.sh <user-id> prd

# Set claims for a user in staging
./deploy/set-firebase-custom-claims.sh <user-id> stg
```

This sets:
- `sign_up_domain`: `labs.pcioasis.com` (or `labs.stg.pcioasis.com` for staging)
- `websiteAccess`: `['labs']`

**Note:** Users may need to sign out and sign in again for custom claims to take effect.

### Firestore Security Rules

Update Firestore security rules to check custom claims:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Primary site collections (www.pcioasis.com only)
    match /primarySiteCollection/{document} {
      allow read, write: if request.auth != null 
        && request.auth.token.websiteAccess != null
        && 'primary' in request.auth.token.websiteAccess;
    }
    
    // Labs collections (labs.pcioasis.com only)
    match /labsCollection/{document} {
      allow read, write: if request.auth != null
        && request.auth.token.sign_up_domain == 'labs.pcioasis.com';
    }
    
    // Shared collections (both sites)
    match /sharedCollection/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

See `docs/FIREBASE_SSO_DESIGN.md` for complete examples and architecture details.

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
# For staging - upload to BOTH projects (required for home services)
./deploy/upload-dotenvx-key.sh stg labs-stg      # For labs services
./deploy/upload-dotenvx-key.sh stg labs-home-stg  # For home services (SEO, Index)

# For production - upload to BOTH projects (required for home services)
./deploy/upload-dotenvx-key.sh prd labs-prd      # For labs services
./deploy/upload-dotenvx-key.sh prd labs-home-prd  # For home services (SEO, Index)
```

**Important:** The secret must exist in **both projects** because:
- Labs services (analytics, labs) run in `labs-stg` / `labs-prd`
- Home services (seo, index) run in `labs-home-stg` / `labs-home-prd`

This script will:
1. Check if the `.env.keys.<env>` file exists
2. Create or update the secret `DOTENVX_KEY_<ENV>` in Secret Manager
3. Automatically grant Cloud Run service account access

### Granting Cloud Run Service Account Access

The script automatically grants access, but if you need to do it manually:

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
- At container startup, use the `dotenvx-startup.sh` script which:
  1. Reads `/etc/secrets/dotenvx-key` and sets it as `DOTENV_PRIVATE_KEY` environment variable
  2. Symlinks `.env.stg` or `.env.prd` → `.env` (based on environment)
  3. Runs the application with `dotenvx run -- <command>`
  4. dotenvx automatically decrypts `.env.<env>` using `DOTENV_PRIVATE_KEY` and injects variables

**How dotenvx Works:**
- dotenvx uses the `DOTENV_PRIVATE_KEY` environment variable to decrypt encrypted `.env` files
- When you run `dotenvx run -- <command>`, it:
  1. Reads the encrypted `.env` file (e.g., `.env.stg`)
  2. Uses `DOTENV_PRIVATE_KEY` to decrypt it
  3. Injects the decrypted environment variables into the process
  4. Your Go code continues using `os.Getenv()` - no code changes needed
- The encrypted `.env.<env>` file stays encrypted in the repo (safe to commit)

**Multiline Values in .env Files:**
- To define multiline values (e.g., JSON service account keys), use double quotes and escape newlines with `\n`
- Example:
  ```
  FIREBASE_SERVICE_ACCOUNT_KEY="{\n  \"type\": \"service_account\",\n  \"project_id\": \"...\"\n}"
  ```
- Some modern dotenv implementations support actual newlines within quoted strings, but using `\n` is more universally compatible
- Use `pcioasis-ops/secrets/dotenvx-converter.py` to encrypt values in place after adding them to the `.env` file

### Secret Mounting in GitHub Actions

The GitHub Actions workflow (`.github/workflows/deploy_labs.yml`) automatically mounts the appropriate secret for each environment:
- **Staging services**: `--update-secrets="/etc/secrets/dotenvx-key:DOTENVX_KEY_STG:latest"`
- **Production services**: `--update-secrets="/etc/secrets/dotenvx-key:DOTENVX_KEY_PRD:latest"`

All Cloud Run deployments (home-seo, home-index, labs-analytics, lab-*-*, labs-index) have the secret mounted automatically.

### Local Development with Docker Compose

For local development, you can run services with or without authentication:

**Without authentication** (default):
```bash
docker-compose up
```
- Services run without dotenvx key mounts
- Uses plain environment variables or unencrypted `.env` files

**With authentication** (matches production):
```bash
# Option 1: Use the helper script (recommended)
./deploy/docker-compose-auth.sh up --build

# Option 2: Manual decryption
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"
dotenvx run --env-file=.env.stg -- docker-compose -f docker-compose.yml -f docker-compose.auth.yml up --build
```
- Decrypts `.env.stg` using `dotenvx` and `.env.keys.stg`
- Sets `FIREBASE_SERVICE_ACCOUNT_KEY`, `FIREBASE_API_KEY`, and `FIREBASE_PROJECT_ID` from decrypted environment variables
- Services automatically detect if `FIREBASE_SERVICE_ACCOUNT_KEY` is set and enable auth
- Mounts `.env.keys.stg` to `/etc/secrets/dotenvx-key` (for consistency with Cloud Run)
- Use when testing Firebase authentication

**Note:** For local sign-in page (`/sign-in`), you also need Firebase web config:

**Two Different Firebase Credentials:**
- `FIREBASE_API_KEY` - Web API key string (client-side Web SDK) - for sign-in page
- `FIREBASE_SERVICE_ACCOUNT_KEY` - Service account JSON (server-side Admin SDK) - for token validation

**Web Config Variables (for sign-in page):**
- `FIREBASE_API_KEY` (or `VITE_APP_FIREBASE_API_KEY` as fallback) - Web API key
- `FIREBASE_AUTH_DOMAIN` - Auth domain (e.g., `ui-firebase-pcioasis-stg.firebaseapp.com`)
- `FIREBASE_STORAGE_BUCKET` - Storage bucket (e.g., `ui-firebase-pcioasis-stg.appspot.com`)
- `FIREBASE_MESSAGING_SENDER_ID` - Messaging sender ID
- `FIREBASE_APP_ID` - App ID

**Where to find:**
- Web API key: Firebase Console → Project Settings → Your apps → Web app → Config → `apiKey`
- Service account JSON: Firebase Console → Project Settings → Service Accounts → Generate new private key

The web API key (`FIREBASE_API_KEY`) is the same value as `VITE_APP_FIREBASE_API_KEY` used in the main e-skimming-app.

**Requirements:**
- `dotenvx` installed: `npm install -g @dotenvx/dotenvx`
- `.env.keys.stg` file in repository root
- `.env.stg` file (encrypted) in repository root

The `docker-compose.auth.yml` override file adds dotenvx key mounts to:
- `home-index`
- `home-seo`
- `labs-analytics`

### Using the Startup Script

To use dotenvx in your Docker containers, update your Dockerfile to:

1. **Copy the startup script**:
   ```dockerfile
   COPY ../dotenvx-startup.sh /dotenvx-startup.sh
   RUN chmod +x /dotenvx-startup.sh
   ```

2. **Install dotenvx** (or let the script install it at runtime):
   ```dockerfile
   RUN npm install -g @dotenvx/dotenvx
   ```

3. **Copy encrypted .env files**:
   ```dockerfile
   COPY .env.stg .env.prd ./
   ```

4. **Update CMD to use the startup script**:
   ```dockerfile
   CMD ["/dotenvx-startup.sh", "./your-binary"]
   ```

The startup script will:
- Read the mounted secret at `/etc/secrets/dotenvx-key` and set it as `DOTENV_PRIVATE_KEY` environment variable
- Symlink the appropriate `.env.<env>` file to `.env` based on `ENVIRONMENT` env var
- Run your application with `dotenvx run -- <command>`
- dotenvx automatically decrypts and injects environment variables - your Go code uses `os.Getenv()` as normal

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
