# Deploy Home Services

Deploys home services to Cloud Run using gcloud commands.

## Services Deployed

| Service | Description |
|---------|-------------|
| `home-seo-stg` | SEO metadata service |
| `home-index-stg` | Main landing page and navigation |

## Usage

```bash
./deploy/deploy-home.sh [stg|prd] [--force-rebuild]
```

### Examples

```bash
# Deploy to staging
./deploy/deploy-home.sh stg

# Deploy to production
./deploy/deploy-home.sh prd

# Force rebuild (no Docker cache)
./deploy/deploy-home.sh stg --force-rebuild
```

## What Gets Deployed

### SEO Service (`home-seo-stg`)

- Provides SEO metadata for pages
- Accessible at `/api/seo`

### Index Service (`home-index-stg`)

- Main landing page
- Lab navigation
- MITRE ATT&CK matrix
- Threat model visualization
- Accessible at `/`, `/mitre-attack`, `/threat-model`

## Source Locations

| Service | Source |
|---------|--------|
| SEO | `deploy/shared-components/seo-service/` |
| Index | `deploy/shared-components/home-index-service/` |

## After Deploying

Restart the local provider to pick up new routes:

```bash
docker compose -f docker-compose.sidecar-local.yml restart provider
```

## Troubleshooting

### Build uses cached layers

Use `--force-rebuild` or manually build with `--no-cache`:

```bash
cd deploy/shared-components/home-index-service
docker build --no-cache -f Dockerfile -t image:tag ../../..
```

**Note:** The home-index Dockerfile uses the repo root as build context.

### Service not starting

Check Cloud Run logs:

```bash
gcloud run services logs read home-index-stg \
  --project=labs-home-stg \
  --region=us-central1 \
  --limit=50
```

### Unused variable errors during build

If you see "declared and not used" errors, the code has leftover variables from old routing logic. Remove them from the source file.

## Manual Deployment

If the script fails, deploy manually:

```bash
# Build (from repo root)
docker build -t us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:latest \
  -f deploy/shared-components/home-index-service/Dockerfile .

# Push
docker push us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:latest

# Deploy
gcloud run deploy home-index-stg \
  --image=us-central1-docker.pkg.dev/labs-home-stg/e-skimming-labs-home/index:latest \
  --project=labs-home-stg \
  --region=us-central1 \
  --no-allow-unauthenticated
```
