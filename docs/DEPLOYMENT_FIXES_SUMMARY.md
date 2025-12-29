# Deployment Fixes and Improvements Summary

This document summarizes all the fixes and improvements made to the deployment and authentication system.

## Quick Links

- **Production Deployment**: `deploy/terraform-home/PRODUCTION_DEPLOYMENT.md`
- **Authentication Architecture**: `docs/AUTHENTICATION_ARCHITECTURE.md`
- **Firebase Setup**: `docs/FIREBASE_SERVICE_ACCOUNT_SETUP.md`

## Key Fixes

### 1. Authentication Architecture Fix

**Problem:** Lab routes (`/lab1`, `/lab2`, `/lab3`) were not protected because they bypass `home-index-service` and go directly to lab containers.

**Solution:** Implemented Traefik ForwardAuth middleware that protects lab routes at the reverse proxy level.

**Files Changed:**
- `deploy/traefik/dynamic/routes.yml` - Added ForwardAuth middleware definitions
- `deploy/shared-components/home-index-service/main.go` - Added `/api/auth/check` endpoint
- `docker-compose.yml` - Added auth middleware to lab routes

**How It Works:**
1. Traefik intercepts requests to `/lab1/*`, `/lab2/*`, `/lab3/*`
2. Traefik forwards to `home-index-service/api/auth/check` to verify authentication
3. If authenticated, request proceeds to lab container
4. If not authenticated, user is redirected to sign-in

**See:** `docs/AUTHENTICATION_ARCHITECTURE.md` for complete details

### 2. Email Verification Requirement

**Problem:** Users could sign up and immediately access protected routes without verifying their email.

**Solution:** Added email verification requirement for all protected routes.

**Files Changed:**
- `deploy/shared-components/home-index-service/main.go` - Sign-up sends verification email, sign-in checks verification
- `deploy/shared-components/home-index-service/auth/middleware.go` - Enforces email verification

**How It Works:**
1. Sign-up automatically sends verification email
2. Sign-in checks if email is verified before allowing access
3. Auth middleware validates email verification status from token claims
4. Unverified users are redirected to sign-in with error message

**See:** `docs/AUTHENTICATION_ARCHITECTURE.md` for complete flow

### 3. Secret Manager Access

**Problem:** Firebase Admin SDK runtime service account couldn't access `DOTENVX_KEY_STG` from Secret Manager.

**Error:**
```
Permission denied on secret: projects/.../secrets/DOTENVX_KEY_STG/versions/latest
for Revision service account fbase-adm-sdk-runtime@labs-home-stg.iam.gserviceaccount.com
```

**Solution:** Added `roles/secretmanager.secretAccessor` to the service account in Terraform.

**File Changed:**
- `deploy/terraform-home/service-accounts.tf` - Added Secret Manager role

**See:** `docs/FIREBASE_SERVICE_ACCOUNT_SETUP.md` - "Secret Manager Access" section

### 4. Production Resource Import

**Problem:** Production resources already existed but weren't in Terraform state, causing "already exists" errors.

**Solution:** Created automated import script and documented manual import process.

**Files Created:**
- `deploy/terraform-home/import-prd.sh` - Automated import script
- `deploy/terraform-home/PRODUCTION_DEPLOYMENT.md` - Complete deployment guide

**Resources Imported:**
- Service accounts (4)
- Artifact Registry repository
- Firestore database
- Storage bucket
- VPC connector (if exists)
- Cloud Run services (2)

**See:** `deploy/terraform-home/PRODUCTION_DEPLOYMENT.md` for complete instructions

### 5. Traefik Service Account IAM Bindings

**Problem:** Terraform tried to create IAM bindings for Traefik service account before it existed.

**Error:**
```
Service account traefik-prd@labs-prd.iam.gserviceaccount.com does not exist
```

**Solution:** Added data source to check if Traefik service account exists, with clear error messages and documentation.

**File Changed:**
- `deploy/terraform-home/iap.tf` - Added data source and improved error handling

**Fix:** Apply `terraform-labs` first to create Traefik service account, then apply `terraform-home`.

**See:** `deploy/terraform-home/PRODUCTION_DEPLOYMENT.md` - "Common Errors and Fixes" section

## Architecture Decisions

### What Terraform Manages

✅ **Service Accounts**: All service accounts and their IAM roles  
✅ **IAM Bindings**: Access control for Cloud Run services  
✅ **Infrastructure**: Artifact Registry, Firestore, Storage, VPC connectors  
✅ **Project APIs**: Required GCP APIs  

### What Terraform Does NOT Manage

❌ **Cloud Run Services**: Managed by GitHub Actions workflows (tracked in state with `lifecycle { ignore_changes = all }`)  
❌ **Service Account Keys**: Created using `gcloud` and managed via scripts in `pcioasis-ops/secrets`  
❌ **Container Images**: Built and pushed by GitHub Actions workflows  

### Authentication Layers

1. **Traefik ForwardAuth** - Protects lab routes (`/lab1`, `/lab2`, `/lab3`) at reverse proxy level
2. **Go Middleware** - Protects lab writeups (`/lab-01-writeup`, etc.) in `home-index-service`
3. **Email Verification** - Enforced for all protected routes

## Deployment Order

### Fresh Production Deployment

1. **terraform-labs** (creates Traefik service account)
2. **terraform-home** (creates home infrastructure and grants Traefik access)
3. **GitHub Actions** (deploys Cloud Run services)

### Importing Existing Production

1. **terraform-home** (import existing resources using `import-prd.sh`)
2. **terraform-labs** (if Traefik doesn't exist yet, or import if it does)
3. **GitHub Actions** (continues managing Cloud Run services)

## Common Commands

### Production Deployment

```bash
# Initialize Terraform
cd deploy/terraform-home
terraform init -reconfigure -backend-config=backend-prd.conf

# Import existing resources
./import-prd.sh

# Plan and apply
terraform plan -var="environment=prd" -var="deploy_services=true"
terraform apply -var="environment=prd" -var="deploy_services=true"
```

### Import Individual Resources

```bash
# Service account
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_service_account.home_seo \
  projects/labs-home-prd/serviceAccounts/home-seo-sa@labs-home-prd.iam.gserviceaccount.com

# Storage bucket
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_storage_bucket.home_assets \
  labs-home-prd-home-assets

# Firestore database
terraform import -var="environment=prd" -var="deploy_services=true" \
  google_firestore_database.home_db \
  projects/labs-home-prd/databases/(default)
```

## Testing Authentication

### Local Development

```bash
# Start services with authentication
./deploy/docker-compose-auth.sh up -d --build

# Test public routes (should work)
curl http://127.0.0.1:8080/
curl http://127.0.0.1:8080/mitre-attack

# Test protected routes (should redirect to sign-in)
curl -v http://127.0.0.1:8080/lab1/  # Should get 302 redirect
curl -v http://127.0.0.1:8080/lab-01-writeup  # Should get 302 redirect
```

### Verify Email Verification

1. Sign up with a new email
2. Check email for verification link
3. Try to sign in before verifying - should see error
4. Verify email
5. Sign in again - should work
6. Access protected route - should work

## Related Documentation

- `docs/AUTHENTICATION_ARCHITECTURE.md` - Complete authentication architecture
- `deploy/terraform-home/PRODUCTION_DEPLOYMENT.md` - Production deployment guide
- `docs/FIREBASE_SERVICE_ACCOUNT_SETUP.md` - Firebase service account setup
- `deploy/secrets/SCRIPTS_SUMMARY.md` - Secrets management scripts
