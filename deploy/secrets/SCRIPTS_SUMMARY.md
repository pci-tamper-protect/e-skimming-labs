# Secrets Management Scripts Summary

This document explains the purpose of each script in the secrets management workflow and whether they should be consolidated.

## Script Overview

### 1. `dotenvx-converter.py` (pcioasis-ops/secrets/)
**Purpose**: Main tool for managing `.env` files with dotenvx encryption

**What it does**:
- Converts `.env` files to dotenvx encrypted format
- Encrypts **only secrets** (pattern-based: KEY, CREDENTIAL, TOKEN, PASSWORD)
- Keeps **config values as plaintext** (readable without decryption)
- Generates SHA256 hashes for secrets (stored in `.env.hashes.<env>`)
- Creates backups before modification
- Scans with trufflehog for exposed secrets (optional)
- Checks `.gitignore` safety

**When to use**:
- After adding/updating secrets in `.env.stg` or `.env.prd`
- To encrypt and hash environment variables
- To update hashes when secrets change

**Example**:
```bash
python3 dotenvx-converter.py .env.stg --env stg
```

**Documentation**: `pcioasis-ops/secrets/DOTENVX_CONVERTER_README.md`

---

### 2. `copy-service-account-to-env.py` (pcioasis-ops/secrets/)
**Purpose**: Specialized helper for Firebase service account keys

**What it does**:
- Reads a Firebase service account JSON key file
- Properly escapes JSON for `.env` file format:
  - Escapes backslashes (`\\`)
  - Escapes double quotes (`\"`)
  - Replaces newlines with `\n`
  - Wraps in double quotes
- Copies to clipboard (macOS) or appends to `.env` file
- Handles existing `FIREBASE_SERVICE_ACCOUNT_KEY` entries (replace or skip)

**When to use**:
- After creating a Firebase service account key
- To add `FIREBASE_SERVICE_ACCOUNT_KEY` to `.env` file
- Before running `dotenvx-converter.py`

**Example**:
```bash
python3 copy-service-account-to-env.py deploy/labs-auth-validator-stg-key.json .env.stg
```

**Documentation**: Inline comments in the script

---

### 3. `create-or-rotate-service-account-key.sh` (e-skimming-labs/deploy/secrets/)
**Purpose**: Complete workflow for creating or rotating service account keys

**What it does**:
1. Checks if the service account key variable already exists in `.env` file
2. If exists, prompts to rotate (or auto-rotates with `--quiet` flag)
3. Creates service account key using `gcloud` (service account must exist in Terraform)
4. Formats it for `.env` file using `copy-service-account-to-env.py`
5. Updates `.env` file with the new key
6. Encrypts and updates hashes using `dotenvx-converter.py`
7. Automatically cleans up the key file

**When to use**:
- After creating service accounts in Terraform
- To set up authentication for services
- To rotate existing keys (quarterly or after security incidents)
- One-time setup or rotation per environment

**Service Accounts for e-skimming-labs**:
```bash
# Firebase Admin SDK Runtime (for home-index-service authentication)
./create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg
./create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-prd.iam.gserviceaccount.com prd

# Home Deploy (for GitHub Actions deployment)
./create-or-rotate-service-account-key.sh home-deploy-sa@labs-home-stg.iam.gserviceaccount.com stg
./create-or-rotate-service-account-key.sh home-deploy-sa@labs-home-prd.iam.gserviceaccount.com prd
```

**Examples**:
```bash
# Create new key (with prompt if exists)
./create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg

# Auto-rotate existing key (no prompt)
./create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg --quiet
```

**Testing**:
```bash
# Test that FIREBASE_SERVICE_ACCOUNT_KEY from .env.stg is valid
cd $HOME/projectos/e-skimming-labs
python3 ../pcioasis-ops/secrets/test_firebase_service_account.py
```

This test verifies:
- The key can be decrypted from `.env.stg`
- It's valid JSON
- It has all required Firebase service account fields
- It's not double-encrypted
- It can initialize Firebase Admin SDK (if `firebase-admin` is installed)

**Documentation**: This file

---

## Should These Be Consolidated?

### ✅ **No consolidation needed** - They serve different purposes:

1. **`dotenvx-converter.py`** - Main tool for dotenvx (`.env` files)
   - Handles encryption, hashing, and backup
   - Works with any environment variables
   - **Keep separate** - core functionality

2. **`copy-service-account-to-env.py`** - Specialized helper
   - Handles JSON escaping for service accounts
   - Could be extended for other JSON-based secrets
   - **Keep separate** - focused utility

3. **`create-or-rotate-service-account-key.sh`** - Workflow orchestrator
   - Combines multiple tools into a single workflow
   - Specific to Firebase Admin SDK setup
   - **Keep separate** - workflow script

### Potential Improvements

1. **Extend `copy-service-account-to-env.py`**:
   - Support other JSON-based secrets (not just Firebase)
   - Rename to `copy-json-secret-to-env.py` for broader use

2. **Create more workflow scripts**:
   - `create-gcp-service-account-key.sh` (generic)
   - `create-github-token.sh` (for GitHub tokens)
   - Each workflow script uses the core tools

3. **Documentation**:
   - ✅ `dotenvx-converter.py` has comprehensive docs
   - ⚠️ `copy-service-account-to-env.py` needs README
   - ✅ `create-or-rotate-service-account-key.sh` documented here

---

## Workflow Examples

### Adding a Firebase Service Account Key

```bash
# 1. Create service account in Terraform
cd deploy/terraform-home
terraform apply

# 2. Create key and update .env files
cd ../secrets
./create-or-rotate-service-account-key.sh fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com stg

# 3. Review and commit
git diff .env.stg .env.hashes.stg
git add .env.stg .env.hashes.stg
git commit -m "Add Firebase Admin SDK service account for staging"
```

### Adding a Generic Secret

```bash
# 1. Add to .env file manually
echo "MY_SECRET_KEY=my-secret-value" >> .env.stg

# 2. Encrypt and update hashes
python3 ../../pcioasis-ops/secrets/dotenvx-converter.py .env.stg --env stg

# 3. Review and commit
git diff .env.stg .env.hashes.stg
```

---

## File Locations

```
pcioasis-ops/secrets/
├── dotenvx-converter.py          # Main dotenvx tool
├── copy-service-account-to-env.py # Firebase SA helper
└── DOTENVX_CONVERTER_README.md   # dotenvx docs

e-skimming-labs/deploy/secrets/
├── create-or-rotate-service-account-key.sh  # Workflow script
└── SCRIPTS_SUMMARY.md                 # This file
```

---

## Summary

**All scripts are correctly separated** and serve distinct purposes:
- ✅ Core tools are reusable and focused
- ✅ Workflow scripts orchestrate multiple tools
- ✅ Uses dotenvx for all secrets management (`.env` files)
- ⚠️ Some scripts need better documentation

**Recommendation**: Keep the current structure, but add README files for the helper scripts.
