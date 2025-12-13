# Shared Resources Between PRD and STG

## ✅ Acceptable Shared Resources

The following resources are intentionally shared between production and staging:

### `pcioasis-operations` Project
- **Purpose**: Shared operations project containing base container images
- **Usage**: Both PRD and STG read base images from `pcioasis-operations/containers`
- **Why Shared**: Base images are infrastructure artifacts, not application data
- **Access**: Read-only access granted to service accounts in both environments

**Base Images Used:**
- `go-base:1.21` - Go build base image
- `alpine-base:3.19` - Alpine runtime base image  
- `nginx-base:1.25` - Nginx base image

## ❌ Resources That Are Now Separate

### Terraform State Buckets
- **PRD**: `e-skimming-labs-terraform-state-prd`
- **STG**: `e-skimming-labs-terraform-state-stg`
- **Status**: ✅ Separate buckets per environment

### GCP Projects
- **PRD**: `labs-prd`, `labs-home-prd`
- **STG**: `labs-stg`, `labs-home-stg`
- **Status**: ✅ Completely separate projects

### Firestore Databases
- **PRD**: Separate databases in `labs-prd` and `labs-home-prd`
- **STG**: Separate databases in `labs-stg` and `labs-home-stg`
- **Status**: ✅ Completely separate databases

### Artifact Registry Repositories
- **PRD**: Repositories in `labs-prd` and `labs-home-prd` projects
- **STG**: Repositories in `labs-stg` and `labs-home-stg` projects
- **Status**: ✅ Separate repositories per environment

### Service Accounts
- **PRD**: `github-actions@labs-prd.iam.gserviceaccount.com`, etc.
- **STG**: `github-actions@labs-stg.iam.gserviceaccount.com`, etc.
- **Status**: ✅ Separate service accounts per environment

### Cloud Storage Buckets
- **PRD**: Buckets in `labs-prd` and `labs-home-prd` projects
- **STG**: Buckets in `labs-stg` and `labs-home-stg` projects
- **Status**: ✅ Separate buckets per environment

### Cloud Run Services
- **PRD**: Services deployed to `labs-prd` and `labs-home-prd`
- **STG**: Services deployed to `labs-stg` and `labs-home-stg`
- **Status**: ✅ Separate services per environment

## Summary

**Only Shared Resource**: `pcioasis-operations` project (base container images - read-only)

**Everything Else**: Completely separate between PRD and STG environments


