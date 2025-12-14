# E-Skimming Labs Deployment Guide

## Prerequisites

Before running any deployment scripts or Terraform commands, authenticate with Google Cloud:

```bash
gcloud auth application-default login
```

This will open a browser for you to authenticate with your Google account. After authentication, Terraform and other tools will use these credentials.

## Overview

The e-skimming-labs infrastructure is split across three separate Terraform modules:

1. **`terraform/`** - Legacy infrastructure (analytics service only)
2. **`terraform-labs/`** - Labs project infrastructure (analytics service)
3. **`terraform-home/`** - Home page project infrastructure (SEO and Index services)

## Deployment Scripts

### 1. Deploy Labs Infrastructure (`deploy-labs.sh`)

Deploys infrastructure for the **labs project** (`labs-stg` or `labs-prd`):
- Artifact Registry repository (`e-skimming-labs`)
- Firestore database
- Cloud Storage buckets
- Service accounts
- **Analytics service** (when `deploy_services=true`)

```bash
./deploy/deploy-labs.sh
```

This script:
- Uses `terraform-labs/` directory
- Sets `deploy_services=true` automatically
- Builds and pushes Docker images before Terraform

### 2. Deploy Home Infrastructure (`deploy-home.sh`)

Deploys infrastructure for the **home project** (`labs-home-stg` or `labs-home-prd`):
- Artifact Registry repository (`e-skimming-labs-home`)
- Service accounts
- **SEO service** (when `deploy_services=true`)
- **Index service** (when `deploy_services=true`)

```bash
./deploy/deploy-home.sh
```

This script:
- Uses `terraform-home/` directory
- Sets `deploy_services=true` automatically
- Builds and pushes Docker images before Terraform

### 3. Legacy Deploy (`deploy.sh`)

**⚠️ DEPRECATED**: This script uses the legacy `terraform/` directory and only deploys the analytics service. Use `deploy-labs.sh` instead.

## Complete Deployment Sequence

To deploy everything for staging:

```bash
# 1. Deploy labs infrastructure (analytics service)
./deploy/deploy-labs.sh

# 2. Deploy home infrastructure (SEO and Index services)
./deploy/deploy-home.sh
```

## Individual Lab Services

The individual lab services (Lab 1: Basic Magecart, Lab 2: DOM Skimming, Lab 3: Extension Hijacking) are **not currently defined in Terraform**. They need to be deployed separately, likely via:

1. **Cloud Build** - Automated deployment via GitHub Actions
2. **Manual deployment** - Using `gcloud run deploy` commands
3. **Future Terraform** - Add lab service definitions to `terraform-labs/`

### Lab Service Locations

- **Lab 1**: `labs/01-basic-magecart/`
- **Lab 2**: `labs/02-dom-skimming/`
- **Lab 3**: `labs/03-extension-hijacking/`

Each lab has its own `Dockerfile` and can be built and deployed independently.

## Service Dependencies

```
┌─────────────────┐
│  Index Service  │ (home project)
│  (Landing Page) │
└────────┬────────┘
         │
         ├──► SEO Service (home project)
         │
         └──► Analytics Service (labs project)
                  │
                  └──► Firestore Database (labs project)
```

## Environment Variables

All deploy scripts read from `.env` files:
- `.env.prd` - Production configuration
- `.env.stg` - Staging configuration
- `.env` - Symlink to either `.env.prd` or `.env.stg`

Required variables:
```bash
LABS_PROJECT_ID=labs-stg          # or labs-prd
LABS_REGION=us-central1
HOME_PROJECT_ID=labs-home-stg     # or labs-home-prd
```

## Troubleshooting

### Only analytics service deployed

If you only see the analytics service, you need to:
1. Run `./deploy/deploy-home.sh` to deploy SEO and Index services
2. Check that `deploy_services=true` is set (it should be automatic)

### Services not deploying

Check that:
- Docker images are built and pushed (run `build-images.sh` first)
- `deploy_services` variable is set to `true` in Terraform
- Service accounts have correct permissions
- Artifact Registry repositories exist

### Individual labs not deployed

Individual lab services are not managed by Terraform yet. They need to be deployed separately via Cloud Build or manual `gcloud` commands.

