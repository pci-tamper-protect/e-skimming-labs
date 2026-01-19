# Deploy Scripts Reference

This document describes all deployment scripts and their usage.

## Quick Reference

| Script | Purpose | Example |
|--------|---------|---------|
| `deploy-all-stg.sh` | Deploy everything to staging | `./deploy/deploy-all-stg.sh` |
| `deploy-home.sh` | Deploy home services (gcloud) | `./deploy/deploy-home.sh stg` |
| `deploy-labs.sh` | Deploy lab services (gcloud) | `./deploy/deploy-labs.sh stg 02` |
| `traefik/deploy-sidecar.sh` | Deploy Traefik gateway | `./deploy/traefik/deploy-sidecar.sh stg` |
| `build-images.sh` | Build Docker images | `./deploy/build-images.sh` |

## Detailed Usage

### deploy-all-stg.sh

Deploys all services to staging environment.

```bash
./deploy/deploy-all-stg.sh
```

This runs:
1. `build-images.sh` - Build all Docker images
2. `deploy-home.sh stg` - Deploy home services
3. `deploy-labs.sh stg all` - Deploy all lab services
4. `traefik/deploy-sidecar.sh stg` - Deploy Traefik gateway

### deploy-home.sh

Deploys home services (home-index, home-seo) to Cloud Run.

```bash
# Deploy to staging
./deploy/deploy-home.sh stg

# Deploy to production
./deploy/deploy-home.sh prd

# Force rebuild (no Docker cache)
./deploy/deploy-home.sh stg --force-rebuild
```

**Services deployed:**
- `home-seo-stg` / `home-seo-prd`
- `home-index-stg` / `home-index-prd`

### deploy-labs.sh

Deploys lab services to Cloud Run.

```bash
# Deploy all labs
./deploy/deploy-labs.sh stg all

# Deploy specific lab
./deploy/deploy-labs.sh stg 01  # Lab 1: Basic Magecart
./deploy/deploy-labs.sh stg 02  # Lab 2: DOM Skimming
./deploy/deploy-labs.sh stg 03  # Lab 3: Extension Hijacking

# Force rebuild
./deploy/deploy-labs.sh stg 02 --force-rebuild

# With custom image tag
./deploy/deploy-labs.sh stg all abc123
```

**Services deployed per lab:**

| Lab | Main Service | C2 Service |
|-----|--------------|------------|
| 01 | `lab-01-basic-magecart-stg` | `lab1-c2-stg` |
| 02 | `lab-02-dom-skimming-stg` | `lab2-c2-stg` |
| 03 | `lab-03-extension-hijacking-stg` | `lab3-extension-stg` |

Also deploys: `labs-analytics-stg`

### traefik/deploy-sidecar.sh

Deploys the Traefik gateway with provider sidecar.

```bash
./deploy/traefik/deploy-sidecar.sh stg
./deploy/traefik/deploy-sidecar.sh prd
```

**Services deployed:**
- `traefik-stg` / `traefik-prd` - Main gateway with provider sidecar
- `traefik-dashboard-stg` / `traefik-dashboard-prd` - Dashboard service

### build-images.sh

Builds Docker images for shared components.

```bash
./deploy/build-images.sh
```

### build-images-optimized.sh

Builds optimized Docker images using golden base images.

```bash
./deploy/build-images-optimized.sh
```

## Terraform Scripts

These scripts manage infrastructure via Terraform. They have a `-tf.sh` suffix.

| Script | Purpose |
|--------|---------|
| `deploy-tf.sh` | Main Terraform deployment |
| `deploy-home-tf.sh` | Terraform for home services |
| `deploy-labs-tf.sh` | Terraform for lab services |
| `terraform-wrapper-tf.sh` | Terraform wrapper utility |
| `create-terraform-state-bucket-tf.sh` | Create state bucket |
| `fix-terraform-state-permissions-tf.sh` | Fix state permissions |
| `unlock-terraform-state-tf.sh` | Unlock stuck state |
| `verify-stg-state-tf.sh` | Verify staging state |
| `fix-stg-state-prd-refs-tf.sh` | Fix state references |

## Environment Configuration

Scripts use `load-env.sh` to load environment variables from `.env` files.

### Setup

1. Create `.env.stg` or `.env.prd` in repo root
2. Create symlink: `ln -s .env.stg .env`
3. For encrypted files, ensure `.env.keys.stg` exists

### Required Variables

```bash
LABS_PROJECT_ID=labs-stg
LABS_REGION=us-central1
HOME_PROJECT_ID=labs-home-stg
```

### Using dotenvx

Scripts use `dotenvx` to decrypt encrypted `.env` files:

```bash
# Install dotenvx
brew install dotenvx/brew/dotenvx

# Decrypt and run
dotenvx run --env-file=.env.stg -fk .env.keys.stg -- printenv
```

## After Deploying

After deploying changes, restart the local provider to pick up new routes:

```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

## Troubleshooting

### Authentication Errors

```bash
# Refresh gcloud auth
gcloud auth login
gcloud auth application-default login
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Docker Cache Issues

Use `--force-rebuild` flag or manually build with `--no-cache`:

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

### Port Conflicts in Multi-Process Containers

Labs with C2 servers run two processes:
- Nginx on port 8080 (Cloud Run's PORT)
- Node.js C2 on port 3000

If the C2 server binds to 8080, it conflicts with Nginx. Check `init.sh` ensures C2 uses port 3000.
