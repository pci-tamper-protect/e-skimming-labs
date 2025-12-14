# Troubleshooting Access to Staging Services

## Problem: "Forbidden" Error When Accessing Staging Services

If you're getting a "Forbidden" error when trying to access `https://home-index-stg-327539540168.us-central1.run.app/`, it's likely because:

1. **You're not in the required Google Groups**: The staging services restrict access to:
   - `group:core-eng@pcioasis.com`
   - `group:2025-interns@pcioasis.com`

2. **IAM bindings haven't been applied**: Terraform may not have created the IAM bindings yet.

## Quick Fix: Add Your User Directly

If you're not in the required groups, you can add your user email directly to the IAM bindings:

```bash
cd deploy/terraform-home
./add-user-access.sh kesten.broughton@pcioasis.com
```

This will grant your user account `roles/run.invoker` on both `home-index-stg` and `home-seo-stg` services.

## Permanent Fix: Use Terraform with Additional Users

Update Terraform to include your user in the `additional_allowed_users` variable:

```bash
cd deploy/terraform-home

# Authenticate first
gcloud auth application-default login

# Initialize Terraform
terraform init -backend-config=backend-stg.conf

# Apply with your user email
terraform apply \
  -var="environment=stg" \
  -var="deploy_services=true" \
  -var='additional_allowed_users=["kesten.broughton@pcioasis.com"]'
```

This will add your user to the IAM bindings and keep it managed by Terraform.

## Verify Access

After adding your user, verify the IAM bindings:

```bash
cd deploy/terraform-home
./verify-iam-bindings.sh
```

Or manually check:

```bash
gcloud run services get-iam-policy home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg \
  --format="table(bindings.role,bindings.members)"
```

You should see your user email with `roles/run.invoker`.

## Proper Long-term Solution: Add User to Google Group

The best long-term solution is to add your user to one of the required Google Groups:

1. **Add to `core-eng@pcioasis.com`** (if you're a core engineer)
2. **Add to `2025-interns@pcioasis.com`** (if you're an intern)

This requires admin access to Google Workspace. Contact your Google Workspace administrator to add you to the appropriate group.

Once you're in a group, the existing Terraform IAM bindings will automatically grant you access.

