# Deployment Guide

This guide covers deploying services to Cloud Run.

## Quick Reference

| What to Deploy | Script | Example |
|----------------|--------|---------|
| Everything | `deploy-all-stg.sh` | `./deploy/deploy-all-stg.sh` |
| Home services | `deploy-home.sh` | `./deploy/deploy-home.sh stg` |
| Lab services | `deploy-labs.sh` | `./deploy/deploy-labs.sh stg 02` |
| Traefik gateway | `deploy-sidecar.sh` | `./deploy/traefik/deploy-sidecar.sh stg` |

## Prerequisites

1. **Authenticate with Google Cloud:**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

2. **Set up environment:**
   ```bash
   # Create .env symlink
   ln -s .env.stg .env
   ```

## Credential Checking

All deploy scripts automatically check credentials before running. If credentials are expired or invalid, the script will abort with instructions.

**Manual credential check:**
```bash
./deploy/check-credentials.sh
```

**What it checks:**
- gcloud auth is active
- Application Default Credentials (ADC) exist
- ADC can generate access tokens (not expired)
- Docker is authenticated to Artifact Registry

**If credentials are expired:**
```bash
gcloud auth login
gcloud auth application-default login
gcloud auth configure-docker us-central1-docker.pkg.dev
```

## Deploy Everything

```bash
./deploy/deploy-all-stg.sh
```

This runs all deployment scripts in order.

## Deploy Specific Components

### Home Services

Deploys `home-index` and `home-seo` services.

```bash
# Deploy to staging
./deploy/deploy-home.sh stg

# Deploy to production
./deploy/deploy-home.sh prd

# Force rebuild (no Docker cache)
./deploy/deploy-home.sh stg --force-rebuild
```

[Full Guide →](./DEPLOY_HOME.md)

### Lab Services

Deploys lab services and analytics.

```bash
# Deploy all labs
./deploy/deploy-labs.sh stg all

# Deploy specific lab
./deploy/deploy-labs.sh stg 01  # Lab 1
./deploy/deploy-labs.sh stg 02  # Lab 2
./deploy/deploy-labs.sh stg 03  # Lab 3

# Force rebuild
./deploy/deploy-labs.sh stg 02 --force-rebuild
```

[Full Guide →](./DEPLOY_LABS.md)

### Traefik Gateway

Deploys the Traefik gateway with provider sidecar.

```bash
./deploy/traefik/deploy-sidecar.sh stg
```

[Full Guide →](./DEPLOY_TRAEFIK.md)

## After Deploying

### Refresh Local Environment

After deploying changes, restart the local provider to pick up new routes:

```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

### Verify Deployment

```bash
# Check service status
gcloud run services list --project=labs-stg --region=us-central1

# Check specific service
gcloud run services describe home-index-stg \
  --project=labs-stg \
  --region=us-central1 \
  --format="value(status.latestReadyRevisionName)"

# View logs
gcloud run services logs read home-index-stg \
  --project=labs-stg \
  --region=us-central1 \
  --limit=50
```

## Troubleshooting

### Authentication Errors

```bash
gcloud auth login
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Docker Cache Issues

Use `--force-rebuild` or manually build with `--no-cache`:

```bash
docker build --no-cache -t image:tag .
```

### Service Not Starting

Check Cloud Run logs:

```bash
gcloud run services logs read SERVICE_NAME \
  --project=labs-stg \
  --region=us-central1 \
  --limit=50
```

### Environment Variables Not Loading

Ensure `.env` symlink exists:

```bash
ls -la .env
# Should show: .env -> .env.stg

# If missing, create it:
ln -s .env.stg .env
```

## Script Reference

### gcloud Scripts (Service Deployment)

| Script | Purpose |
|--------|---------|
| `deploy-all-stg.sh` | Deploy everything to staging |
| `deploy-home.sh` | Deploy home services |
| `deploy-labs.sh` | Deploy lab services |
| `traefik/deploy-sidecar.sh` | Deploy Traefik gateway |
| `build-images.sh` | Build Docker images |

### Terraform Scripts (Infrastructure)

| Script | Purpose |
|--------|---------|
| `deploy-tf.sh` | Main Terraform deployment |
| `deploy-home-tf.sh` | Terraform for home services |
| `deploy-labs-tf.sh` | Terraform for lab services |

## Next Steps

- [Testing deployed services](../testing/STAGING_TESTING.md)
- [Local development](../getting-started/LOCAL_SIDECAR.md)
- [Troubleshooting](../troubleshooting/README.md)
