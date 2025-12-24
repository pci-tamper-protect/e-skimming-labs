# STG Environment Verification Guide

This guide helps verify that STG and PRD environments are properly separated and there are no hardcoded PRD references.

## Quick Verification

### 1. Check STG State for PRD Resources

```bash
cd deploy
./verify-stg-state.sh
```

This script checks all Terraform state files for PRD project references.

### 2. Check GCP STG Projects for Misnamed Resources

```bash
cd deploy
./check-stg-resources.sh
```

This script checks GCP STG projects for resources with `-prd` naming.

### 3. Verify .env Configuration

```bash
cd deploy
ls -la .env
# Should show: .env -> .env.stg (or .env.prd)
```

## Environment Configuration

The environment is determined by the `.env` symlink:

- **STG**: `ln -s .env.stg .env`
- **PRD**: `ln -s .env.prd .env`

All deploy scripts automatically:
1. Source the `.env` file
2. Determine environment from project ID (`-stg` vs `-prd`)
3. Use the correct backend config (`backend-stg.conf` vs `backend-prd.conf`)
4. Pass correct project IDs to Terraform

## Terraform Wrapper Script

For manual Terraform commands, use the wrapper script:

```bash
cd deploy
./terraform-wrapper.sh terraform plan
./terraform-wrapper.sh terraform-labs apply
./terraform-wrapper.sh terraform-home init
```

The wrapper automatically:
- Reads `.env` to determine environment
- Uses correct backend config
- Passes correct project IDs and variables

## Hardcoded PRD References

### ✅ Safe (Default Values Only)

These are just defaults and get overridden by `.env`:
- `deploy/terraform/variables.tf`: `default = "labs-prd"`
- `deploy/terraform-labs/variables.tf`: `default = "labs-prd"`
- `deploy/terraform-home/variables.tf`: `default = "labs-home-prd"` and `default = "labs-prd"`

### ✅ Fixed

- GitHub Actions workflow: Now uses environment-based project IDs from `setup` job outputs
- Deploy scripts: All use `.env` to determine environment

## Common Issues

### Issue: Terraform using wrong backend

**Solution**: Make sure `.env` points to correct file:
```bash
cd deploy
rm .env
ln -s .env.stg .env  # for staging
# or
ln -s .env.prd .env  # for production
```

### Issue: Resources imported into wrong state

**Solution**: Use `terraform state rm` to remove, then re-import with correct project ID.

### Issue: GCP resources have wrong naming

**Solution**: Check with `check-stg-resources.sh` and rename/delete misnamed resources.

## Verification Checklist

Before deploying to STG:

- [ ] `.env` symlink points to `.env.stg`
- [ ] `verify-stg-state.sh` passes (no PRD resources in STG state)
- [ ] `check-stg-resources.sh` passes (no `-prd` naming in STG projects)
- [ ] Terraform plan shows correct project IDs (should be `labs-stg` or `labs-home-stg`)
- [ ] Backend config is `backend-stg.conf` (check Terraform init output)

