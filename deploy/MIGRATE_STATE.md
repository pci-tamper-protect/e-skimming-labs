# Migrating Local Terraform State to GCS Backend

## Problem
You previously deployed Terraform locally, so you have local `.tfstate` files. Now you're switching to a GCS backend, but you need to:
1. Fix permissions on the state bucket
2. Migrate your local state to GCS

## Step 1: Fix Bucket Permissions

```bash
./deploy/fix-terraform-state-permissions.sh
```

This will grant your user account the necessary permissions to read/write state files in the environment-specific bucket.

## Step 2: Migrate Local State to GCS

**IMPORTANT**: You must specify the backend config file when running `terraform init`. The backend config file tells Terraform which bucket to use.

For each Terraform configuration, use the appropriate backend config file:

### Main Infrastructure (deploy/terraform)
```bash
cd deploy/terraform

# For PRODUCTION:
terraform init -backend-config=backend-prd.conf -migrate-state

# OR for STAGING:
terraform init -backend-config=backend-stg.conf -migrate-state

# Terraform will detect your local state and ask:
# "Do you want to copy existing state to the new backend?"
# Answer: yes
```

### Labs Infrastructure (deploy/terraform-labs)
```bash
cd deploy/terraform-labs

# For PRODUCTION:
terraform init -backend-config=backend-prd.conf -migrate-state

# OR for STAGING:
terraform init -backend-config=backend-stg.conf -migrate-state

# Answer: yes when prompted
```

### Home Infrastructure (deploy/terraform-home)
```bash
cd deploy/terraform-home

# For PRODUCTION:
terraform init -backend-config=backend-prd.conf -migrate-state

# OR for STAGING:
terraform init -backend-config=backend-stg.conf -migrate-state

# Answer: yes when prompted
```

**Note**: If you don't specify `-backend-config`, Terraform will prompt you interactively for the bucket name, which is not recommended.

## Step 3: Verify Migration

After migration, verify the state is in GCS (use environment-specific bucket):

```bash
# For production
gsutil ls gs://e-skimming-labs-terraform-state-prd/labs/terraform/
gsutil ls gs://e-skimming-labs-terraform-state-prd/labs/terraform-labs/
gsutil ls gs://e-skimming-labs-terraform-state-prd/home/terraform-home/

# For staging
gsutil ls gs://e-skimming-labs-terraform-state-stg/labs/terraform/
gsutil ls gs://e-skimming-labs-terraform-state-stg/labs/terraform-labs/
gsutil ls gs://e-skimming-labs-terraform-state-stg/home/terraform-home/
```

You should see `default.tfstate` files in each directory.

## Step 4: Clean Up Local State (Optional)

After successful migration and verification, you can remove local state files:

```bash
# Backup first!
cd deploy/terraform
cp terraform.tfstate terraform.tfstate.backup

# Remove local state (Terraform will now use GCS)
rm terraform.tfstate terraform.tfstate.backup
```

**Note**: Only do this after verifying everything works with the GCS backend!

## Troubleshooting

### "Access denied" errors
- Run `./deploy/fix-terraform-state-permissions.sh` again
- Verify your account: `gcloud config get-value account`
- Check bucket IAM: `gsutil iam get gs://e-skimming-labs-terraform-state-{prd|stg}`

### "State file not found" after migration
- Check if the state file exists: `gsutil ls gs://e-skimming-labs-terraform-state-{prd|stg}/**/*.tfstate`
- Verify the prefix in backend config files matches the path in GCS
- Try `terraform init -reconfigure -backend-config=backend-{prd|stg}.conf` to reinitialize

### State conflicts
- If you have multiple state files, you may need to merge them manually
- Use `terraform state pull` to download state, merge, then `terraform state push` to upload

