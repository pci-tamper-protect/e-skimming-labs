# PRD ↔ STG Alignment Guide

**Goal:** Align `labs-prd` and `labs-home-prd` GCP projects with `labs-stg` and `labs-home-stg` so production matches the evolved staging setup.

**Approach:** Use `deploy/` scripts wherever possible instead of raw gcloud/terraform commands.

---

## Quick Start: Align PRD in Order

```bash
# 1. Point env at PRD
ln -sf .env.prd .env

# 2. Credentials
source deploy/check-credentials.sh && check_credentials

# 3. Terraform (labs first, then home)
# If PRD resources already exist, run import scripts before apply:
#   ./deploy/terraform-home/import-prd.sh
#   ./deploy/terraform-labs/import-prd.sh
./deploy/terraform/deploy-labs-tf.sh
./deploy/terraform/deploy-home-tf.sh

# 4. Traefik provider SA + IAM
./deploy/traefik/iam.sh prd
./deploy/traefik/APPLY_PERMISSIONS.sh prd

# 5. Secret Manager
./deploy/upload-dotenvx-key.sh prd labs-prd
./deploy/upload-dotenvx-key.sh prd labs-home-prd

# 6. GitHub secrets
./deploy/add-all-github-secrets.sh
```

---

## 1. GitHub Secrets Required

The deploy workflow uses **environment-specific** secrets. Ensure all are set:

| Secret | Used For | How to Set |
|--------|----------|------------|
| `GCP_LABS_SA_KEY_STG` | Deploy to labs-stg | See [deploy/secrets/](deploy/secrets/) + manual `gh secret set` |
| `GCP_LABS_SA_KEY_PRD` | Deploy to labs-prd | See [deploy/secrets/](deploy/secrets/) + manual `gh secret set` |
| `GCP_HOME_SA_KEY_STG` | Deploy to labs-home-stg | `./deploy/add-github-secrets-home.sh` (target stg via .env) |
| `GCP_HOME_SA_KEY_PRD` | Deploy to labs-home-prd | `./deploy/add-github-secrets-home.sh` (target prd via .env) |
| `TRAEFIK_PROVIDER_SA_KEY_STG` | E2E tests, local dev | `./deploy/traefik/iam.sh stg` |
| `TRAEFIK_PROVIDER_SA_KEY_PRD` | PRD route discovery | `./deploy/traefik/iam.sh prd` |
| `GH_PAT` | (Optional) API rate limits | GitHub Personal Access Token |

**Note:** `add-all-github-secrets.sh` and `add-github-secrets-home.sh` set `GCP_LABS_SA_KEY` / `GCP_HOME_SA_KEY`. The workflow prefers `GCP_*_SA_KEY_STG` and `GCP_*_SA_KEY_PRD`. After running the add scripts, you may need to copy values to the env-specific secret names via `gh secret set`.

**Actions (use deploy scripts):**

```bash
# 1. Traefik provider SA for PRD (creates SA, grants IAM, uploads to TRAEFIK_PROVIDER_SA_KEY_PRD)
./deploy/traefik/iam.sh prd

# 2. Deploy SA keys for PRD (labs + home) — uses labs-prd and labs-home-prd
./deploy/add-all-github-secrets.sh
# Sets GCP_LABS_SA_KEY, GCP_HOME_SA_KEY. Workflow uses these as fallback when GCP_*_SA_KEY_PRD unset.
# For env-specific secrets, copy to GCP_LABS_SA_KEY_PRD / GCP_HOME_SA_KEY_PRD via gh secret set.
```

---

## 2. GCP Service Accounts (Terraform)

Both environments use the same Terraform modules. Ensure PRD Terraform has been applied.

### labs-prd / labs-stg (terraform-labs)

| Service Account | Purpose |
|----------------|---------|
| `labs-runtime-sa` | Cloud Run lab services |
| `labs-deploy-sa` | CI/CD deployment |
| `labs-analytics-sa` | Analytics service |
| `labs-seo-sa` | SEO service |
| `traefik-prd` / `traefik-stg` | Traefik reverse proxy |

### labs-home-prd / labs-home-stg (terraform-home)

| Service Account | Purpose |
|----------------|---------|
| `home-runtime-sa` | Cloud Run home services |
| `home-deploy-sa` | CI/CD deployment |
| `home-seo-sa` | SEO service |
| `fbase-adm-sdk-runtime` | Firebase Admin SDK (auth) |

### traefik-provider-token-sa (not in Terraform)

Created by `./deploy/traefik/iam.sh`. Exists in **labs-stg** and **labs-prd** (not labs-home).

**Action:** Run `./deploy/traefik/iam.sh prd` if not done.

---

## 3. Terraform Apply Order

1. **terraform-labs** (creates Traefik SA, labs SAs)
2. **terraform-home** (references Traefik SA from labs project)
3. **traefik/iam.sh** (creates traefik-provider-token-sa)

**PRD Terraform (use deploy scripts):**

```bash
# Point .env at PRD (scripts read LABS_PROJECT_ID, HOME_PROJECT_ID from .env)
ln -sf .env.prd .env

# 1. Labs project (uses load-env.sh → LABS_PROJECT_ID from .env.prd)
./deploy/terraform/deploy-labs-tf.sh

# 2. Home project (uses HOME_PROJECT_ID from .env)
./deploy/terraform/deploy-home-tf.sh

# 3. Traefik provider SA (not in Terraform)
./deploy/traefik/iam.sh prd
```

**If PRD resources already exist:** Run import scripts before apply:

```bash
./deploy/terraform-home/import-prd.sh    # Imports home SAs, services, etc.
./deploy/terraform-labs/import-prd.sh    # Imports labs resources
```

---

## 4. Secret Manager (DOTENVX Keys)

| Project | Secret | Used By |
|---------|--------|---------|
| labs-stg | `DOTENVX_KEY_STG` | Lab services in labs-stg |
| labs-home-stg | `DOTENVX_KEY_STG` | home-index-stg, home-seo-stg |
| labs-prd | `DOTENVX_KEY_PRD` | Lab services in labs-prd |
| labs-home-prd | `DOTENVX_KEY_PRD` | home-index-prd, home-seo-prd |

**Action (use deploy script):**

```bash
# Upload to both PRD projects (script handles create/update + IAM for fbase-adm-sdk-runtime)
./deploy/upload-dotenvx-key.sh prd labs-prd
./deploy/upload-dotenvx-key.sh prd labs-home-prd
```

**Prerequisite:** `.env.keys.prd` must exist (from dotenvx setup).

---

## 5. APIs to Enable

`deploy/terraform-home/main.tf` includes `secretmanager.googleapis.com` for DOTENVX_KEY access. Running `./deploy/terraform/deploy-home-tf.sh` will enable it. No manual gcloud needed.

---

## 6. IAM Permissions (Apply Scripts)

Run these to align PRD with STG:

```bash
# Traefik + labs-deploy run.viewer on both projects
./deploy/traefik/APPLY_PERMISSIONS.sh prd
```

This grants:
- `traefik-prd@labs-prd`: `roles/run.viewer` on labs-prd and labs-home-prd
- `labs-deploy-sa@labs-prd`: `roles/run.viewer` on labs-home-prd (for HOME_INDEX_URL fetch)

---

## 7. Cross-Project IAM (terraform-home)

terraform-home grants:
- `traefik-{env}@labs-{env}`: `roles/run.invoker` on home-seo and home-index
- `traefik-{env}@labs-{env}`: `roles/run.viewer` on labs-home-{env}
- `labs-deploy-sa@labs-{env}`: `roles/run.viewer` on labs-home-{env}

These are created by Terraform. Ensure `terraform-home` has been applied for PRD.

---

## 8. Firebase Project

| Environment | Firebase Project |
|-------------|------------------|
| stg | `ui-firebase-pcioasis-stg` |
| prd | `ui-firebase-pcioasis-prd` |

`fbase-adm-sdk-runtime@labs-home-{env}` needs `roles/firebase.admin` on the Firebase project. This is in `terraform-home/service-accounts.tf`.

---

## 9. Artifact Registry

| Project | Repository |
|---------|------------|
| labs-stg / labs-prd | `e-skimming-labs` |
| labs-home-stg / labs-home-prd | `e-skimming-labs-home` |

Terraform creates these via `./deploy/terraform/deploy-labs-tf.sh` and `./deploy/terraform/deploy-home-tf.sh`. Verify with:

```bash
./deploy/traefik/check-permissions.sh prd   # Checks Artifact Registry in labs-prd
```

---

## 10. Checklist: Match PRD to STG

- [ ] **GitHub Secrets**
  - [ ] `./deploy/traefik/iam.sh prd` → TRAEFIK_PROVIDER_SA_KEY_PRD
  - [ ] `./deploy/add-all-github-secrets.sh` → GCP_LABS_SA_KEY, GCP_HOME_SA_KEY (fallbacks for PRD)

- [ ] **Terraform**
  - [ ] `ln -sf .env.prd .env` then `./deploy/terraform/deploy-labs-tf.sh`
  - [ ] `./deploy/terraform/deploy-home-tf.sh`
  - [ ] If resources exist: `./deploy/terraform-home/import-prd.sh`, `./deploy/terraform-labs/import-prd.sh`

- [ ] **Secret Manager**
  - [ ] `./deploy/upload-dotenvx-key.sh prd labs-prd`
  - [ ] `./deploy/upload-dotenvx-key.sh prd labs-home-prd`

- [ ] **IAM**
  - [ ] `./deploy/traefik/APPLY_PERMISSIONS.sh prd`
  - [ ] `./deploy/traefik/iam.sh prd` (traefik-provider-token-sa)

- [ ] **Firebase**
  - [ ] `ui-firebase-pcioasis-prd` exists
  - [ ] fbase-adm-sdk-runtime@labs-home-prd has firebase.admin (Terraform)

---

## 11. Verification (use deploy scripts)

```bash
# Credentials and auth
source deploy/check-credentials.sh && check_credentials

# Artifact Registry permissions
./deploy/traefik/check-permissions.sh prd

# Cloud Run access control (uses .env for LABS_PROJECT_ID, HOME_PROJECT_ID)
ln -sf .env.prd .env
./deploy/verify-access-control.sh
```

**Manual checks (when scripts don't cover):**

```bash
gcloud secrets describe DOTENVX_KEY_PRD --project=labs-prd
gcloud secrets describe DOTENVX_KEY_PRD --project=labs-home-prd
```

---

## 12. Deploy Scripts Reference

| Script | Purpose |
|--------|---------|
| `deploy/check-credentials.sh` | Verify gcloud, ADC, Docker auth |
| `deploy/load-env.sh` | Load .env via dotenvx (used by terraform deploy scripts) |
| `deploy/terraform/deploy-labs-tf.sh` | Apply terraform-labs (uses .env) |
| `deploy/terraform/deploy-home-tf.sh` | Apply terraform-home (uses .env) |
| `deploy/terraform-home/import-prd.sh` | Import existing PRD resources into Terraform state |
| `deploy/terraform-labs/import-prd.sh` | Import existing PRD labs resources |
| `deploy/traefik/iam.sh` | Create traefik-provider-token-sa, upload key to GitHub |
| `deploy/traefik/APPLY_PERMISSIONS.sh` | Grant run.viewer to Traefik + labs-deploy on both projects |
| `deploy/upload-dotenvx-key.sh` | Upload DOTENVX_KEY_* to Secret Manager |
| `deploy/add-all-github-secrets.sh` | Add GCP_LABS_SA_KEY, GCP_HOME_SA_KEY for labs-prd + labs-home-prd |
| `deploy/verify-access-control.sh` | Verify Cloud Run IAM (stg vs prd) |
| `deploy/traefik/check-permissions.sh` | Check Artifact Registry permissions |
