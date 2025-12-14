# Cloud Run Access Control Status

## Summary

**Staging (stg) Environment**: ✅ All services are protected from public access
- Only `2025-interns@pcioasis.com` and `core-eng@pcioasis.com` groups can access
- No `allUsers` (public) access granted

**Production (prd) Environment**: ✅ All services are publicly accessible
- `allUsers` access granted for public-facing services

## Staging Services Protection

### ✅ Protected via Terraform (`iap.tf`)

1. **Labs Project (`labs-stg`)**:
   - `labs-analytics-stg` - ✅ Protected (groups: 2025-interns, core-eng)
   - Note: Individual lab services are deployed via GitHub Actions (see below)

2. **Home Project (`labs-home-stg`)**:
   - `home-seo-stg` - ✅ Protected (groups: 2025-interns, core-eng)
   - `home-index-stg` - ✅ Protected (groups: 2025-interns, core-eng)

### ✅ Protected via GitHub Actions (`deploy_labs.yml`)

1. **Labs Project (`labs-stg`)**:
   - `labs-analytics-stg` - ✅ Protected (deployed with `--no-allow-unauthenticated`, groups added)
   - `labs-index-stg` - ✅ Protected (deployed with `--no-allow-unauthenticated`, groups added)
   - `lab-01-basic-magecart-stg` - ✅ Protected (deployed with `--no-allow-unauthenticated`, groups added)
   - `lab-02-dom-skimming-stg` - ✅ Protected (deployed with `--no-allow-unauthenticated`, groups added)
   - `lab-03-extension-hijacking-stg` - ✅ Protected (deployed with `--no-allow-unauthenticated`, groups added)
   - Any other lab services - ✅ Protected (same pattern)

2. **Home Project (`labs-home-stg`)**:
   - `home-seo-stg` - ✅ Protected (deployed with `--no-allow-unauthenticated`, groups added)
   - `home-index-stg` - ✅ Protected (deployed with `--no-allow-unauthenticated`, groups added)

## Production Services Access

### ✅ Public Access (as intended)

1. **Labs Project (`labs-prd`)**:
   - `labs-analytics-prd` - ✅ Public (`--allow-unauthenticated`)
   - `labs-index-prd` - ✅ Public (`--allow-unauthenticated`)
   - `lab-*-prd` services - ✅ Public (`--allow-unauthenticated`)

2. **Home Project (`labs-home-prd`)**:
   - `home-seo-prd` - ✅ Public (`allUsers` via Terraform)
   - `home-index-prd` - ✅ Public (`allUsers` via Terraform)

## Service Account Access (Internal)

Some services have service account bindings for **service-to-service** calls:
- `analytics_runtime_access` - Allows `labs-runtime-sa` to invoke analytics service
- This is **internal** access, not public access
- Used for lab services to call analytics service

## Verification

To verify access control, run:

```bash
cd deploy
./verify-access-control.sh
```

This script will:
- Check all Cloud Run services in the configured environment
- Verify no `allUsers` access in staging
- Verify group access (2025-interns, core-eng) in staging
- Verify public access in production

## Configuration Files

### Terraform IAM Bindings
- `deploy/terraform-labs/iap.tf` - Analytics service group access
- `deploy/terraform-home/iap.tf` - SEO and Index service group access

### Terraform Public Access (Production)
- `deploy/terraform-home/cloud-run.tf` - Public access for SEO and Index (production only)

### GitHub Actions Deployment
- `.github/workflows/deploy_labs.yml` - All services deployed with environment-specific access:
  - Staging: `--no-allow-unauthenticated` + group IAM bindings
  - Production: `--allow-unauthenticated`

## Notes

1. **Dual Protection**: Some services are protected both via Terraform (`iap.tf`) and GitHub Actions. This is intentional redundancy to ensure protection even if one method fails.

2. **Service Account Access**: Service account bindings (e.g., `analytics_runtime_access`) are for **internal service-to-service** communication and do not grant public access.

3. **Environment Detection**: Access control is automatically determined by the `environment` variable:
   - `stg` → Restricted to groups
   - `prd` → Public access

4. **No Public Access in Staging**: All staging services explicitly use `--no-allow-unauthenticated` and only grant access to specific groups.

