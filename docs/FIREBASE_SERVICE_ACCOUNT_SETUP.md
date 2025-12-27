# Firebase Service Account Setup for E-Skimming Labs

## Overview

E-Skimming Labs uses **two different Firebase credentials**:

## Service Account Management: Terraform vs gcloud

**Important separation of concerns:**

| Tool | Manages | Purpose |
|------|---------|---------|
| **Terraform** | Service accounts and IAM bindings | Infrastructure as code, version control, permissions |
| **gcloud** | Service account keys | Credentials (keys) for runtime use |

**Why this separation?**
- **Terraform** ensures service accounts and permissions are defined in code, versioned, and reproducible
- **gcloud** is used for one-time key generation (keys are secrets, not infrastructure)
- Keys should be created manually/on-demand, not stored in Terraform state

**Workflow:**
1. **Terraform** creates the service account and IAM bindings (one-time setup)
2. **gcloud** creates service account keys as needed (can create multiple keys)
3. Keys are added to `.env` files and encrypted with dotenvx

1. **`FIREBASE_API_KEY`** - Web API key (client-side Web SDK)
   - Format: String starting with `AIzaSy...` (typically 39 characters)
   - Used for: Client-side Firebase Web SDK (sign-in page)
   - **Note**: Semi-secret (client-side but detected by secret scanners)
   - Already in your `.env.stg` ✅

2. **`FIREBASE_SERVICE_ACCOUNT_KEY`** - Service account JSON (server-side Admin SDK)
   - Format: JSON string (single line, escaped)
   - Used for: Server-side token validation (Go backend)
   - **Needs to be added to `.env.stg`** ⚠️

## Service Accounts Requiring Keys

The following service accounts need keys created for e-skimming-labs. Copy the command for the service account and environment you need:

```bash
# Firebase Admin SDK Runtime (for home-index-service authentication)
./deploy/secrets/create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg
./deploy/secrets/create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-prd.iam.gserviceaccount.com prd

# Home Deploy (for GitHub Actions deployment)
./deploy/secrets/create-or-rotate-service-account-key.sh home-deploy-sa@labs-home-stg.iam.gserviceaccount.com stg
./deploy/secrets/create-or-rotate-service-account-key.sh home-deploy-sa@labs-home-prd.iam.gserviceaccount.com prd
```

## Setup: Two Simple Steps

### Step 1: Run Terraform

Create the service account and IAM bindings:

```bash
cd deploy/terraform-home
gcloud auth application-default login
terraform init -backend-config=backend-stg.conf  # or backend-prd.conf for production
terraform apply
```

This creates:
- Service account: `fbase-adm-sdk-runtime@labs-home-{env}.iam.gserviceaccount.com`
- IAM bindings in the home project
- Cross-project IAM binding for Firebase Admin SDK access

### Step 2: Create Key and Update .env Files

Run the script to create the key, update `.env` files, and encrypt (requires access to pcioasis-ops/secrets):

```bash
cd /Users/kestenbroughton/projectos/e-skimming-labs
./deploy/secrets/create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg
./deploy/secrets/create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-prd.iam.gserviceaccount.com prd
```

This script (which calls the general-purpose script in `pcioasis-ops/secrets`) automatically:
- ✅ Verifies service account exists (created by Terraform)
- ✅ Creates service account key using `gcloud`
- ✅ Formats and adds it to `.env.stg` as `FIREBASE_SERVICE_ACCOUNT_KEY`
- ✅ Encrypts the `.env.stg` file and updates hashes
- ✅ Removes the key file (security best practice)

**That's it!** The service account is now configured and ready to use.

**Note**: The general-purpose script `create-service-account-key-and-update-env.sh` in `pcioasis-ops/secrets` can be used for any service account, not just Firebase Admin SDK.

## Alternative: Manual Setup (If Needed)

If you need to add a service account key manually:

### Option A: Use Helper Script (Recommended)

If you have the service account key file:

```bash
# From e-skimming-labs directory
../../pcioasis-ops/secrets/copy-service-account-to-env.sh deploy/labs-auth-validator-stg-key.json .env.stg
```

This script:
- Formats the JSON correctly (single line, escaped)
- Adds it to `.env.stg` as `FIREBASE_SERVICE_ACCOUNT_KEY`
- Handles multiline JSON properly

### Option B: Manual Format

If adding manually, the JSON must be on a **single line** with escaped quotes and newlines:

```bash
FIREBASE_SERVICE_ACCOUNT_KEY="{\"type\":\"service_account\",\"project_id\":\"ui-firebase-pcioasis-stg\",\"private_key_id\":\"...\",\"private_key\":\"-----BEGIN PRIVATE KEY-----\\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\\n-----END PRIVATE KEY-----\\n\",\"client_email\":\"labs-auth-validator@ui-firebase-pcioasis-stg.iam.gserviceaccount.com\",\"client_id\":\"...\",\"auth_uri\":\"https://accounts.google.com/o/oauth2/auth\",\"token_uri\":\"https://oauth2.googleapis.com/token\",\"auth_provider_x509_cert_url\":\"https://www.googleapis.com/oauth2/v1/certs\",\"client_x509_cert_url\":\"...\"}"
```

**Important formatting rules:**
- Entire JSON on one line
- Escape all double quotes: `"` → `\"`
- Escape newlines in private key: `\n` → `\\n`
- Wrap entire value in double quotes

### Option C: Using jq (if you have the key file)

```bash
# Format the JSON file to single line with escaped quotes
jq -c . deploy/labs-auth-validator-stg-key.json | sed 's/"/\\"/g' | sed 's/^/FIREBASE_SERVICE_ACCOUNT_KEY="/' | sed 's/$/"/' >> .env.stg
```

## Verify Setup

Test that the service account is correctly formatted:

```bash
# Decrypt and check
export DOTENV_PRIVATE_KEY="$(cat .env.keys.stg)"
dotenvx run --env-file=.env.stg -- sh -c 'echo "$FIREBASE_SERVICE_ACCOUNT_KEY" | jq -r .client_email' 2>/dev/null | tail -1
```

Expected output:
```
labs-auth-validator@ui-firebase-pcioasis-stg.iam.gserviceaccount.com
```

If you get an error, the JSON format is incorrect.

## Complete Example

Here's what your `.env.stg` should look like (before encryption):

```bash
# Firebase Web API Key (client-side) - Semi-secret (masked in docs)
FIREBASE_API_KEY=AIzaSy...<masked>...  # 39 characters, starts with AIzaSy
FIREBASE_PROJECT_ID=ui-firebase-pcioasis-stg
FIREBASE_AUTH_DOMAIN=ui-firebase-pcioasis-stg.firebaseapp.com
FIREBASE_APP_ID=1:927793065963:web:3f2480209231602a4e33ae

# Firebase Service Account JSON (server-side Admin SDK)
FIREBASE_SERVICE_ACCOUNT_KEY="{\"type\":\"service_account\",\"project_id\":\"ui-firebase-pcioasis-stg\",\"private_key_id\":\"abc123...\",\"private_key\":\"-----BEGIN PRIVATE KEY-----\\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\\n-----END PRIVATE KEY-----\\n\",\"client_email\":\"labs-auth-validator@ui-firebase-pcioasis-stg.iam.gserviceaccount.com\",\"client_id\":\"123456789\",\"auth_uri\":\"https://accounts.google.com/o/oauth2/auth\",\"token_uri\":\"https://oauth2.googleapis.com/token\",\"auth_provider_x509_cert_url\":\"https://www.googleapis.com/oauth2/v1/certs\",\"client_x509_cert_url\":\"https://www.googleapis.com/robot/v1/metadata/x509/labs-auth-validator%40ui-firebase-pcioasis-stg.iam.gserviceaccount.com\"}"
```

## How It's Used in Code

### Client-Side (Browser)
- Uses `FIREBASE_API_KEY` for Firebase Web SDK
- Used in sign-in page, client-side auth

### Server-Side (Go Backend)
- Uses `FIREBASE_SERVICE_ACCOUNT_KEY` for Firebase Admin SDK
- Validates Firebase ID tokens from clients
- Checks user authentication status

The code in `deploy/shared-components/home-index-service/main.go`:
```go
firebaseServiceAccount := os.Getenv("FIREBASE_SERVICE_ACCOUNT_KEY")
// ... 
authConfig := auth.Config{
    CredentialsJSON: firebaseServiceAccount,  // Service account JSON
    // ...
}
```

## Troubleshooting

### Error: "invalid character 'e' looking for beginning of value"

This means `FIREBASE_SERVICE_ACCOUNT_KEY` is not valid JSON. Check:
1. Is it on a single line?
2. Are all quotes escaped (`\"`)?
3. Are newlines in private key escaped (`\\n`)?

### Error: "FIREBASE_SERVICE_ACCOUNT_KEY not found"

The variable isn't in `.env.stg`. Add it using one of the methods above.

### Service Account Not Working

Verify the service account exists:
```bash
gcloud iam service-accounts describe labs-auth-validator@ui-firebase-pcioasis-stg.iam.gserviceaccount.com --project=ui-firebase-pcioasis-stg
```

## Quick Reference

**Variable Name:** `FIREBASE_SERVICE_ACCOUNT_KEY`

**Format:** JSON string (single line, escaped)

**Source:** Firebase Console → Project Settings → Service Accounts → Generate new private key

**Helper Script:** `../../pcioasis-ops/secrets/copy-service-account-to-env.sh`

**Encryption:** Use `dotenvx-converter.py` to encrypt after adding
